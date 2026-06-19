import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';
import '../shared/illustration.dart';
import 'chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  // Custom history panel (instead of Scaffold.drawer) so the swipe-to-close
  // gesture works from anywhere, including the shaded scrim.
  late final AnimationController _panel =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _panel.dispose();
    super.dispose();
  }

  void _openPanel() => _panel.forward();
  void _closePanel() => _panel.reverse();

  double get _panelW => MediaQuery.of(context).size.width * 0.72;

  // Drive the panel directly so it follows the finger (0 = closed, 1 = open).
  void _onPanelDrag(DragUpdateDetails d) =>
      _panel.value += (d.primaryDelta ?? 0) / _panelW;

  // On release, settle open or closed by fling velocity, else by position.
  void _settlePanel(DragEndDetails d) {
    final vx = d.primaryVelocity ?? 0;
    if (vx.abs() > 400) {
      vx > 0 ? _panel.forward() : _panel.reverse();
    } else {
      _panel.value > 0.5 ? _panel.forward() : _panel.reverse();
    }
  }

  void _send() {
    final text = _input.text;
    final pending = ref.read(pendingImageProvider);
    if (text.trim().isEmpty && pending == null) return;
    if (pending != null && pending.uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hang on, your photo is still uploading.')));
      return;
    }
    _input.clear();
    ref.read(pendingImageProvider.notifier).state = null;
    ref.read(chatControllerProvider.notifier).send(text, imagePath: pending?.path);
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
    final bg = Theme.of(context).scaffoldBackgroundColor;
    ref.listen(chatControllerProvider, (_, __) => WidgetsBinding.instance
        .addPostFrameCallback((_) => _followBottom()));
    final panelW = _panelW;

    return Stack(
      children: [
        Scaffold(
          // No AppBar — a detached, rounded header floats in the body instead.
          // Right-swipe anywhere in the chat body opens the history panel.
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _onPanelDrag,
            onHorizontalDragEnd: _settlePanel,
            child: Stack(
              children: [
                // Messages fill the full height; they scroll down toward the
                // composer and fade into the background (see the gradient below).
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _ChatHeader(
                        subject: state.subject,
                        topic: state.topic,
                        tokens: t,
                        onMenu: _openPanel,
                        onNew: () => ref.read(chatControllerProvider.notifier).reset(),
                      ),
                      Expanded(
                        child: state.messages.isEmpty
                            ? const _EmptyChat()
                            : ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(24, 12, 24, 150),
                                itemCount: state.messages.length,
                                itemBuilder: (_, i) =>
                                    ChatBubble(msg: state.messages[i], onGrow: _followBottom),
                              ),
                      ),
                    ],
                  ),
                ),
                // Soft fade: instead of a solid background block, the content
                // dissolves into the page colour toward the bottom so the
                // composer floats over it.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 190,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bg.withValues(alpha: 0.0), bg],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
                // Floating composer (no background block of its own).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.limit != null) _LimitBanner(limit: state.limit!),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => SizeTransition(
                          sizeFactor: anim,
                          alignment: const Alignment(-1, -1),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: (!ref.watch(hasSmarterModelProvider) && state.messages.isEmpty)
                            ? _FreeModelNote(
                                key: const ValueKey('freenote'),
                                tokens: t,
                                onTap: () => context.push('/premium'))
                            : const SizedBox.shrink(key: ValueKey('nofreenote')),
                      ),
                      _Composer(controller: _input, sending: state.sending, onSend: _send, tokens: t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // History panel overlay. Positioned.fill so the scrim covers the WHOLE
        // screen — without it the Stack shrinks to the panel width and only a
        // vertical band gets dimmed. Tap or swipe-left (panel or scrim) closes.
        Positioned.fill(
          child: AnimatedBuilder(
          animation: _panel,
          builder: (context, _) {
            if (_panel.value == 0) return const SizedBox.shrink();
            final v = Curves.easeOut.transform(_panel.value);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePanel,
                    onHorizontalDragUpdate: _onPanelDrag,
                    onHorizontalDragEnd: _settlePanel,
                    child: ColoredBox(color: Colors.black.withValues(alpha: 0.45 * v)),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-panelW * (1 - v), 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: _onPanelDrag,
                    onHorizontalDragEnd: _settlePanel,
                    child: Container(
                      width: panelW,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        // Muted tone so the panel reads distinctly from the
                        // white surfaces (incl. the bottom nav bar).
                        color: t.surfaceMuted,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                      // Material provides ink/splash for the list items inside.
                      child: Material(
                        color: Colors.transparent,
                        child: _HistoryPanel(onClose: _closePanel),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ],
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
              'Explain a concept, mark your working, or find a practice question. Grounded in real Singapore A-Level material and the SEAB syllabus.',
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.coffee_rounded, color: t.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Text(limit.message,
                  style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600))),
        ]),
        // Anonymous users hit a small daily cap — surface a one-tap sign-up.
        if (Supabase.instance.client.auth.currentUser == null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/signin'),
              child: const Text('Sign up free'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Slim free-tier notice: the free model can be inconsistent on maths; tapping
/// opens Premium. Hidden for paid users.
class _FreeModelNote extends StatelessWidget {
  final AppTokens tokens;
  final VoidCallback onTap;
  const _FreeModelNote({super.key, required this.tokens, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(FF.rField),
        child: InkWell(
          borderRadius: BorderRadius.circular(FF.rField),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Icon(Icons.functions_rounded, size: 16, color: tokens.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(
                  style: TextStyle(color: tokens.textMuted, fontSize: 12, height: 1.35),
                  children: [
                    const TextSpan(text: 'Free tier model may be inaccurate at times. '),
                    TextSpan(
                      text: "Consider upgrading if you'd like more reliable answers.",
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                )),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: tokens.textMuted),
            ]),
          ),
        ),
      ),
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
    final pending = ref.watch(pendingImageProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: _StyleToggle(
                value: style,
                tokens: tokens,
                onChanged: (v) {
                  notifier.setAnswerStyle(v);
                  ref.read(chatControllerProvider.notifier).noteStyle(v);
                },
              ),
            ),
            // Detached, rounded chatbox card — floats on the page (there is no
            // enclosing rectangle/bar behind it + the toggle).
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (pending != null) _AttachPreview(pending: pending, tokens: tokens),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                IconButton(
                  icon: Icon(Icons.add_rounded, color: tokens.textMuted),
                  tooltip: 'Attach a photo',
                  onPressed: () => _attachPhoto(context, ref),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question or paste an exam question...',
                      hintMaxLines: 1,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                    onPressed: sending ? null : onSend,
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Photo upload is a paid (Lite+), signed-in feature. Gate, then pick → show an
  /// instant preview → upload in the background. `_send` reads the result.
  Future<void> _attachPhoto(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!ref.read(canPhotoProvider)) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Photo upload is a Lactic Lite feature.'),
        action: SnackBarAction(label: 'Upgrade', onPressed: () => context.push('/premium')),
      ));
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Sign in to attach a photo.'),
        action: SnackBarAction(label: 'Sign in', onPressed: () => context.push('/signin')),
      ));
      return;
    }
    final uploads = ref.read(uploadServiceProvider);
    final XFile? file = await uploads.pick(ImageSource.gallery);
    if (file == null) return; // cancelled
    final bytes = await file.readAsBytes();
    ref.read(pendingImageProvider.notifier).state = PendingImage(bytes: bytes);
    try {
      final path = await uploads.upload(file, bytes);
      // The user may have cleared/replaced the attachment mid-upload — only
      // commit the path if our bytes are still the pending ones.
      if (ref.read(pendingImageProvider)?.bytes == bytes) {
        ref.read(pendingImageProvider.notifier).state =
            PendingImage(bytes: bytes, path: path);
      }
    } catch (_) {
      if (ref.read(pendingImageProvider)?.bytes == bytes) {
        ref.read(pendingImageProvider.notifier).state = null;
      }
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not upload that photo. Try again.')));
    }
  }
}

/// Small thumbnail of the attached photo shown above the input, with a spinner
/// while it uploads and an ✕ to remove it.
class _AttachPreview extends ConsumerWidget {
  final PendingImage pending;
  final AppTokens tokens;
  const _AttachPreview({required this.pending, required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(pending.bytes,
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
            if (pending.uploading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => ref.read(pendingImageProvider.notifier).state = null,
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.textMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detached, rounded header that floats over the chat (replaces the AppBar):
/// menu on the left, title centered, new-chat on the right.
class _ChatHeader extends StatelessWidget {
  final String? subject;
  final String? topic;
  final AppTokens tokens;
  final VoidCallback onMenu;
  final VoidCallback onNew;
  const _ChatHeader({
    required this.subject,
    required this.topic,
    required this.tokens,
    required this.onMenu,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(FF.rCard),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          IconButton(tooltip: 'Chats', icon: const Icon(Icons.menu_rounded), onPressed: onMenu),
          Expanded(
            child: topic == null
                ? Text('New chat', textAlign: TextAlign.center, style: theme.textTheme.titleMedium)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (subject != null && subject!.isNotEmpty) ? subject! : 'Tutor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(topic!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
          IconButton(tooltip: 'New chat', icon: const Icon(Icons.edit_outlined), onPressed: onNew),
        ],
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

/// Left history panel (ChatGPT-style): New chat at the top, search, and the
/// list of past conversations. Hosted in a custom overlay by [ChatScreen] so it
/// can be opened and dismissed by swiping from anywhere (panel or scrim).
class _HistoryPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const _HistoryPanel({required this.onClose});
  @override
  ConsumerState<_HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<_HistoryPanel> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var convos = ref.watch(conversationStoreProvider).list();
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      convos = convos.where((c) => c.title.toLowerCase().contains(q) || c.subject.toLowerCase().contains(q)).toList();
    }
    return SafeArea(
      child: Column(
        children: [
          // New chat
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FF.rButton),
                side: BorderSide(color: t.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(FF.rButton),
                onTap: () {
                  ref.read(chatControllerProvider.notifier).reset();
                  widget.onClose();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(Icons.add_rounded, color: t.onPrimarySoft),
                    const SizedBox(width: 12),
                    Text('New chat',
                        style: TextStyle(color: t.onPrimarySoft, fontWeight: FontWeight.w700, fontSize: 15.5)),
                  ]),
                ),
              ),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search chats',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: convos.isEmpty
                ? Center(
                    child: Text(_q.isEmpty ? 'No chats yet' : 'No matches',
                        style: TextStyle(color: t.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: convos.length,
                    itemBuilder: (_, i) {
                      final c = convos[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: t.border),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              ref.read(chatControllerProvider.notifier).load(c);
                              widget.onClose();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                  if (c.subject.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(c.subject,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: t.textMuted, fontSize: 12.5)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
