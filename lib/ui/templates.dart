import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../game/controller.dart';
import '../game/palette.dart';

/// Escolha do modelo para uma fase nova. Devolve o id do modelo, ou null se fechar.
Future<String?> pickTemplate(BuildContext context, Palette c) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.paper,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('Criar fase'), style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 2),
              Text(tr('Comece de um modelo; dá para mudar tudo depois.'), style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: c.muted)),
              const SizedBox(height: 8),
              for (final (id, name, desc, from) in kTemplates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(from == null ? Icons.crop_landscape : Icons.copy_all_outlined, color: c.ink),
                  title: Text(tr(name), style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink)),
                  subtitle: Text(tr(desc), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
                  onTap: () => Navigator.of(ctx).pop(id),
                ),
            ]),
          ),
        ),
      ),
    );
