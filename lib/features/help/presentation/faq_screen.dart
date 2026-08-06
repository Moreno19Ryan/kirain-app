import 'package:flutter/material.dart';

import '../data/support_contact.dart';

const _faqs = [
  (
    question: 'Apa itu KIRAIN?',
    answer:
        'KIRAIN itu asisten keuangan yang bantu kamu mikir sebelum belanja, '
        'bukan cuma nyatet setelah kejadian. Fitur utamanya: bedain Wajib '
        'vs Keinginan tiap transaksi, biar kamu sadar ke mana aja duit kamu '
        'pergi.',
  ),
  (
    question: 'Data keuangan aku aman gak?',
    answer:
        'Aman. Data kamu tersimpan di Supabase, gak dibagi atau dijual ke '
        'pihak ketiga mana pun. Detail lengkapnya ada di Kebijakan Privasi.',
  ),
  (
    question: 'Bedanya Wajib sama Keinginan apa?',
    answer:
        'Wajib itu kebutuhan yang emang harus dipenuhi (makan, transportasi, '
        'tagihan, dll). Keinginan itu yang sebenernya bisa ditunda atau '
        'dikurangin (jajan, hiburan, belanja). Kamu yang nentuin sendiri '
        'tiap transaksi masuk yang mana.',
  ),
  (
    question: 'Bisa dipakai bareng pasangan/keluarga?',
    answer:
        'Untuk sekarang, KIRAIN masih per akun pribadi. Fitur budget bareng '
        '(shared budget) lagi direncanain buat versi berikutnya.',
  ),
  (
    question: 'KIRAIN gratis?',
    answer: 'Iya, KIRAIN gratis dipakai.',
  ),
  (
    question: 'Gimana kalau mau hapus akun?',
    answer:
        'Tinggal buka halaman Kamu, scroll ke bawah, terus pilih "Hapus '
        'Akun". Bisa langsung dari situ, gak perlu hubungi siapa-siapa — '
        'tapi inget, sekali dihapus gak bisa dikembalikan lagi.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final faq in _faqs)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(faq.question),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(faq.answer),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text('Masih bingung?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Chat atau email kami, nanti dibantu ya.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _launch(context, SupportContact.openWhatsApp),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Chat via WhatsApp'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _launch(context, SupportContact.openEmail),
            icon: const Icon(Icons.email_outlined),
            label: Text('Email ke ${SupportContact.email}'),
          ),
        ],
      ),
    );
  }
}

Future<void> _launch(BuildContext context, Future<bool> Function() open) async {
  bool succeeded;
  try {
    succeeded = await open();
  } catch (_) {
    succeeded = false;
  }

  if (!succeeded && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yah, gak bisa buka itu. Coba lagi ya.')),
    );
  }
}
