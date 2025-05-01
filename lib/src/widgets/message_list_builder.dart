import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // <-- Import do flutter_markdown

import '../constants/app_colors.dart';

class MessageListBuilder extends StatelessWidget {
  const MessageListBuilder({
    super.key,
    required FocusNode textFieldFocusNode,
    required ScrollController scrollController,
    required List<Map<String, String>> messages,
    required this.isLoading,
  })  : _textFieldFocusNode = textFieldFocusNode,
        _scrollController = scrollController,
        _messages = messages;

  final FocusNode _textFieldFocusNode;
  final ScrollController _scrollController;
  final List<Map<String, String>> _messages;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final totalItems = _messages.length + (isLoading ? 1 : 0);

    return GestureDetector(
      onTap: () => _textFieldFocusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(8.0),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Se chegamos no final da lista e isLoading == true, mostrar "bubble de digitação"
          if (index == _messages.length && isLoading) {
            return _buildTypingBubble();
          }

          // Caso contrário, renderiza as mensagens normalmente
          final msg = _messages[index];
          final bool isUser = msg['role'] == 'user';

          return Padding(
            padding: EdgeInsets.only(
              top: isUser ? 8.0 : 12.0,
              bottom: isUser ? 12.0 : 8.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                // Mensagens do "assistant"
                if (!isUser) ...[
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: AppColors.senderBubbleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/icon.png',
                          height: 16,
                          width: 16,
                        ),
                      ],
                    ),
                  ),

                  // Exibe o Markdown em uma "bolha"
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8, right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.senderBubbleColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MarkdownBody(
                        data: msg['content'] ?? '',
                        // Personalize o estilo do Markdown (cores, fontes etc.)
                        styleSheet: MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ).copyWith(
                          p: const TextStyle(
                            fontFamily: 'sv-pro',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTapLink: (text, url, title) {
                          // Se quiser abrir links externos, usar url_launcher etc.
                        },
                      ),
                    ),
                  ),
                ],

                // Mensagens do "user"
                if (isUser) ...[
                  BubbleSpecialThree(
                    text: msg['content'] ?? '',
                    color: AppColors.senderBubbleColor,
                    tail: true,
                    textStyle: const TextStyle(
                      fontFamily: 'sv-pro',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Retorna o bubble de digitação (avatar + 3 bolinhas animadas)
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar do "assistant"
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: AppColors.senderBubbleColor,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  height: 16,
                  width: 16,
                ),
              ],
            ),
          ),

          // Bolha contendo as 3 bolinhas animadas
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 8, right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.senderBubbleColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TypingIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exibe as 3 bolinhas animadas, simulando "digitando..."
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Controlador para animar as bolinhas em loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Retorna um widget "pontinho" com animação
  Widget _buildDot(int index) {
    // Cada bolinha aparece em uma fase diferente
    final start = index * 0.2;
    final end = start + 0.4;

    // Anima a escala de 0.5 até 1.0
    final animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3 bolinhas
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}
