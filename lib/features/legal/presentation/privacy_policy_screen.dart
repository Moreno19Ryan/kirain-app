import 'package:flutter/material.dart';

import 'legal_section.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          LegalSection(
            title: 'Data apa yang KIRAIN simpan?',
            body:
                'Email kamu (buat login pakai kode OTP) dan data yang kamu '
                'input sendiri: transaksi, kategori, target nabung, dan '
                'pengaturan budget. Gak ada data lain yang diambil diam-diam.',
          ),
          LegalSection(
            title: 'Buat apa data itu dipakai?',
            body:
                'Cuma buat nyalain fitur di dalam app — nyatet transaksi, '
                'ngitung progress budget wajib/keinginan, ngasih rekap, dan '
                'nyimpen target nabung kamu. Gak dipakai buat hal lain.',
          ),
          LegalSection(
            title: 'Di mana data disimpan?',
            body:
                'Di Supabase, sebagai penyedia layanan backend (data '
                'processor) — bukan pihak yang memiliki atau berhak pakai '
                'data kamu buat kepentingan lain. Data kamu tetap milik kamu.',
          ),
          LegalSection(
            title: 'Dibagi ke pihak ketiga?',
            body:
                'Gak. Data kamu gak dijual atau dibagi ke pihak ketiga mana '
                'pun selain Supabase, semata-mata karena Supabase adalah '
                'infrastruktur yang KIRAIN pakai buat nyimpen datanya.',
          ),
          LegalSection(
            title: 'Kontrol kamu atas data',
            body:
                'Mau hapus akun beserta semua datanya? Hubungi kami lewat WA '
                'atau email di halaman Bantuan, nanti dibantu prosesnya.',
          ),
          LegalSection(
            title: 'Ada pertanyaan?',
            body: 'Hubungi kami lewat WA atau email di halaman Bantuan.',
          ),
        ],
      ),
    );
  }
}
