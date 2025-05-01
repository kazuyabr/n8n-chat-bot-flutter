import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:iconsax/iconsax.dart';

// IMPORTANTE: adicionar o pacote shared_preferences no pubspec.yaml
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_colors.dart';
import 'widgets/message_list_builder.dart';
import 'package:n8nchatgpt/src/constants/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final FocusNode _textFieldFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Aqui armazenaremos o userId recuperado ou criado
  String? _userId;

  // Lista de mensagens
  final List<Map<String, String>> _messages = [];

  // Variáveis de estado
  bool _isListening = false;
  bool _isTextFieldFocused = false;
  bool _isTextNotEmpty = false;
  bool _isLoading = false; // Indica se o agente está "digitando"
  String _text = '';
  int _textFieldLines = 1;
  final int _lineLimit = 1;

  // Variável para controlar se o áudio está ativado ou desativado (default: false)
  bool _audioEnabled = false;

  @override
  void initState() {
    super.initState();

    // Recupera ou cria o userId no momento da inicialização
    _retrieveOrCreateUserId().then((_) {
      // Após obter/criar o userId, carrega as mensagens salvas do SharedPreferences
      _loadMessages();
    });

    // Carregar preferência de áudio
    _loadAudioPreference();

    _textFieldFocusNode.addListener(() {
      setState(() {
        _isTextFieldFocused = _textFieldFocusNode.hasFocus;
      });

      if (_textFieldFocusNode.hasFocus) {
        scrollToBottom();
      }
    });

    _textController.addListener(() {
      setState(() {
        _isTextNotEmpty = _textController.text.trim().isNotEmpty;
      });
    });
  }

  /// Verifica se já existe um `userId` salvo no SharedPreferences.
  /// Caso não exista, cria um novo e salva localmente.
  Future<void> _retrieveOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUserId = prefs.getString('userId');

    // Caso não exista, cria e salva.
    if (storedUserId == null) {
      final newUserId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('userId', newUserId);
      storedUserId = newUserId;
    }

    setState(() {
      _userId = storedUserId;
    });
  }

  /// Carrega o estado do áudio (ativado/desativado) do SharedPreferences
  Future<void> _loadAudioPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _audioEnabled = prefs.getBool('audioEnabled') ?? false;
    });
  }

  /// Carrega as mensagens salvas no SharedPreferences
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chatMessages');
    if (messagesJson != null) {
      final List<dynamic> decodedList = jsonDecode(messagesJson);
      _messages.clear();
      for (var item in decodedList) {
        if (item is Map<String, dynamic>) {
          _messages.add({
            'role': item['role'] ?? '',
            'content': item['content'] ?? '',
          });
        }
      }
      setState(() {});
    }
  }

  /// Salva as mensagens atuais no SharedPreferences
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatMessages', jsonEncode(_messages));
  }

  /// Mostra um diálogo de confirmação para limpeza do histórico
  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpar histórico'),
          content: const Text('Deseja realmente apagar todo o histórico de mensagens?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Apagar'),
              onPressed: () {
                Navigator.of(context).pop();
                _clearChatHistory();
              },
            ),
          ],
        );
      },
    );
  }

  /// Limpa todo o histórico de mensagens e salva o estado
  Future<void> _clearChatHistory() async {
    setState(() {
      _messages.clear();
    });
    await _saveMessages();
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _startListening() async {
    _textFieldFocusNode.unfocus();
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() => _text = result.recognizedWords);
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_text.isNotEmpty) {
      final message = _text;
      _textController.text = message;
      _text = '';
      _sendMessage(message);
    }
    _textController.clear();
  }

  Future<void> _sendMessage(String userMessage) async {
    if (_userId == null) {
      debugPrint('Ainda não foi possível obter o userId.');
      return;
    }

    // Exibe a mensagem do usuário no chat
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
    });
    await _saveMessages();
    scrollToBottom();

    // Início do estado de "agente digitando"
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(Config.webhook),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_usuario': _userId,
          'mensagem': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiReply = data[0]['output'];

        setState(() {
          _messages.add({'role': 'assistant', 'content': aiReply});
        });
        await _saveMessages();

        // Agora não usamos mais Config.speak, mas sim a variável local _audioEnabled
        if (_audioEnabled) {
          await _speak(aiReply);
        }
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Erro: ${response.statusCode} - '
                '${json.decode(response.body)['error'] ?? 'Erro desconhecido'}',
          });
        });
        await _saveMessages();
      }
    } catch (e) {
      debugPrint('Erro: $e');
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Desculpe, ocorreu um erro na comunicação com o servidor.',
        });
      });
      await _saveMessages();
    } finally {
      // Fim do estado de "agente digitando"
      setState(() {
        _isLoading = false;
      });
      scrollToBottom();
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Ícone de áudio no canto superior esquerdo
        leading: IconButton(
          icon: Icon(
            _audioEnabled ? Icons.volume_up : Icons.volume_off,
          ),
          onPressed: () async {
            setState(() {
              _audioEnabled = !_audioEnabled;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('audioEnabled', _audioEnabled);
          },
        ),
        title: const Text(
          Config.appname,
          style: TextStyle(
            fontFamily: 'sv-pro',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.backgroundColor,
        scrolledUnderElevation: 0,

        // Botão de lixeira no canto superior direito
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Lista de mensagens + bubble de digitação (caso _isLoading == true)
            Expanded(
              child: MessageListBuilder(
                textFieldFocusNode: _textFieldFocusNode,
                scrollController: _scrollController,
                messages: _messages,
                isLoading: _isLoading, // Passamos o estado de "digitação"
              ),
            ),

            // Campo de texto + botões (enviar/mic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textfieldBackgroundColor,
                        borderRadius: BorderRadius.circular(
                          _textFieldLines > _lineLimit ? 48 : 24,
                        ),
                        border: Border.all(
                          color: AppColors.textfieldBackgroundColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: _isTextFieldFocused ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _textFieldFocusNode,
                                  maxLines: null,
                                  minLines: 1,
                                  cursorColor: AppColors.primaryColor,
                                  style: const TextStyle(
                                    fontFamily: 'sv-pro',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: Config.placeholder,
                                    hintStyle: TextStyle(
                                      fontFamily: 'sv-pro',
                                      // ignore: deprecated_member_use
                                      color: AppColors.labelSecondary.withOpacity(0.6),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (text) {
                                    final lines = '\n'.allMatches(text).length + 1;
                                    if (lines != _textFieldLines) {
                                      setState(() {
                                        _textFieldLines = lines;
                                      });
                                    }
                                  },
                                ),
                              ),
                              _isTextFieldFocused ? _buildSendButton() : _buildMicButton(),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(
        bottom: _textFieldLines > _lineLimit ? 0 : 8,
      ),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      // ignore: deprecated_member_use
      color: _isTextNotEmpty ? AppColors.primaryColor : AppColors.disableColor.withOpacity(0.18),
      child: SizedBox(
        height: 32,
        width: 32,
        child: InkWell(
          onTap: _isTextNotEmpty
              ? () {
                  final message = _textController.text.trim();
                  if (message.isNotEmpty) {
                    _sendMessage(message);
                    _textController.clear();
                  }
                }
              : null,
          child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return IconButton(
      onPressed: _isListening ? _stopListening : _startListening,
      icon: Icon(
        _isListening ? Iconsax.microphone_slash_1 : Iconsax.microphone_2,
        color: AppColors.gray2,
        size: 30,
      ),
    );
  }
}
