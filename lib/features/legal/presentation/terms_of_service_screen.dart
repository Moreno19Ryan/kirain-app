import 'package:flutter/material.dart';

import 'legal_section.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Syarat & Ketentuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          LegalSection(
            title: 'Tentang KIRAIN',
            body:
                'KIRAIN adalah alat bantu pencatatan keuangan pribadi. '
                'KIRAIN BUKAN bank, e-wallet, atau layanan finansial '
                'berlisensi — jadi jangan simpan/transfer uang beneran lewat '
                'app ini, KIRAIN cuma nyatet.',
          ),
          LegalSection(
            title: 'Akun kamu',
            body:
                'Kamu tanggung jawab jagain keamanan login (kode OTP) kamu '
                'sendiri. Minimal berusia 17 tahun, atau sudah cukup umur '
                'menurut hukum yang berlaku di negara kamu buat pakai layanan '
                'digital semacam ini.',
          ),
          LegalSection(
            title: 'Data kamu, punya kamu',
            body:
                'Semua data transaksi, kategori, dan target nabung yang kamu '
                'catat tetap milik kamu sepenuhnya.',
          ),
          LegalSection(
            title: 'Bukan penasihat keuangan',
            body:
                'KIRAIN bantu kamu mikir & mencatat, tapi bukan penasihat '
                'keuangan resmi. Keputusan finansial tetap di tangan kamu, '
                'dan KIRAIN gak bisa bertanggung jawab atas kerugian yang '
                'timbul dari keputusan itu.',
          ),
          LegalSection(
            title: 'Yang gak boleh dilakukan',
            body:
                'Jangan reverse-engineer, jangan pakai KIRAIN buat aktivitas '
                'ilegal, dan jangan disalahgunakan buat merugikan orang lain.',
          ),
          LegalSection(
            title: 'Perubahan layanan',
            body:
                'KIRAIN bisa berubah dari waktu ke waktu — fitur bisa '
                'ditambah, diubah, atau dihapus seiring app berkembang.',
          ),
          LegalSection(
            title: 'Penghentian akun',
            body:
                'Kalau ada penyalahgunaan atau pelanggaran ketentuan ini, '
                'KIRAIN berhak menghentikan atau suspend akun kamu.',
          ),
          LegalSection(
            title: 'Kontak & sengketa',
            body:
                'Ada pertanyaan atau keberatan? Hubungi kami lewat WA atau '
                'email di halaman Bantuan — kita selesaikan baik-baik.',
          ),
          SizedBox(height: 12),
          Text(
            'Dokumen ini masih draft awal dari solo developer, belum '
            'direview lawyer — bakal diupdate seiring KIRAIN berkembang.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
