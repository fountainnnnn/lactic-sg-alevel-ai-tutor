import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';
import '../shared/illustration.dart';
import 'streaming_text.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// Keep the view pinned to the bottom as the answer types in — but only if
  /// the user is already near the bottom, so scrolling up to re-read isn't
  /// fought. jumpTo (not animateTo) avoids animations stacking each frame.
  void _followBottom() {
    if (_scroll.hasClients) {
      final p = _scroll.position;
      if (p.maxScrollExtent - p.pixels < 260) _scroll.jumpTo(p.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final t = context.tokens;
    ref.listen(chatControllerProvider, (_, __) => WidgetsBinding.instance
        .addPostFrameCallback((_) => _followBottom()));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('JCAI'),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => ref.read(chatControllerProvider.notifier).reset(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    itemCount: state.messages.length,
                    itemBuilder: (_, i) =>
                        _Bubble(msg: state.messages[i], onGrow: _followBottom),
                  ),
          ),
          if (state.limit != null) _LimitBanner(limit: state.limit!),
          _Composer(controller: _input, sending: state.sending, onSend: _send, tokens: t),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final VoidCallback? onGrow;
  const _Bubble({required this.msg, this.onGrow});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    if (msg.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 56, bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.primarySoft,
            border: Border.all(color: t.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(FF.rBubble),
              topRight: Radius.circular(FF.rBubble),
              bottomLeft: Radius.circular(FF.rBubble),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.content,
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, height: 1.45)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 40, bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: t.border),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FF.rBubble),
          topRight: Radius.circular(FF.rBubble),
          bottomRight: Radius.circular(FF.rBubble),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // tutor identity line
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('JCAI',
                style: TextStyle(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 8),
          if (msg.content.isEmpty && msg.streaming)
            const _Typing()
          else
            StreamingText(
              text: msg.content,
              done: !msg.streaming,
              onGrow: onGrow,
            ),
          if (msg.citations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Divider(height: 1, color: t.border),
            ),
            // compact numbered pills — a legend for the inline [#n] citations;
            // the full source name is on the tooltip (long-press / hover).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: msg.citations
                  .map((c) => Tooltip(
                        message: c.ref,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: t.border),
                          ),
                          child: Text('#${c.n}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.onPrimarySoft)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 14, color: t.success),
              const SizedBox(width: 5),
              Text('GROUNDED IN ${msg.citations.length} SOURCE${msg.citations.length == 1 ? '' : 'S'}',
                  style: TextStyle(fontSize: 11, color: t.success, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: context.tokens.textMuted),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Illustration('empty_chats', size: 150),
            const SizedBox(height: 12),
            Text('Ask me anything', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Explain a concept, mark your working, or find a practice question. I cite real Singapore prelims and the syllabus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitBanner extends StatelessWidget {
  final LimitException limit;
  const _LimitBanner({required this.limit});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceMuted,
        borderRadius: BorderRadius.circular(FF.rCard),
        border: Border.all(color: t.border),
      ),
      child: Row(children: [
        Icon(Icons.coffee_rounded, color: t.warning),
        const SizedBox(width: 10),
        Expanded(
            child: Text(limit.message,
                style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _Composer extends ConsumerWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final AppTokens tokens;
  const _Composer(
      {required this.controller, required this.sending, required this.onSend, required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(settingsProvider).answerStyle;
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: tokens.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StyleToggle(
              value: style,
              tokens: tokens,
              onChanged: notifier.setAnswerStyle,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(hintText: 'Ask anything…'),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.photo_camera_outlined, color: tokens.textMuted),
                tooltip: 'Photo a question',
                onPressed: () {},
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  onPressed: sending ? null : onSend,
                  child: sending
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded, size: 20),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StyleToggle extends StatelessWidget {
  final String value;
  final AppTokens tokens;
  final ValueChanged<String> onChanged;
  const _StyleToggle({required this.value, required this.tokens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String key, String label) {
      final on = value == key;
      return GestureDetector(
        onTap: () => onChanged(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Theme.of(context).colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: on ? Border.all(color: tokens.border) : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? tokens.onPrimarySoft : tokens.textMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: tokens.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('coach', 'Guide me'),
        seg('direct', 'Just answer'),
      ]),
    );
  }
}
