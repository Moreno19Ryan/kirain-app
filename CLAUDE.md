# KIRAIN — Spesifikasi Produk & Teknis (v1 Planning Doc)

> Dokumen ini adalah hasil kompilasi brainstorming lengkap soal aplikasi KIRAIN. Ditulis biar bisa jadi rujukan utama (termasuk buat Claude Code) pas mulai eksekusi coding, mockup, dan roadmap.

---

## 0. Aturan Kerja (WAJIB DIBACA SEBELUM EKSEKUSI APAPUN)

> Bagian ini berlaku buat Claude Code (atau instance Claude manapun) yang kerja langsung di codebase KIRAIN.

- **JANGAN** jalankan migration atau perubahan skema database apapun tanpa konfirmasi eksplisit dari Reno berupa **"OK, jalankan"**. Ini pelajaran mahal dari insiden production migration tanpa approval di GENSITI — jangan diulang di sini.
- **Project Supabase**: pastikan selalu kerja di project **development/staging**, BUKAN project production, kecuali sudah dikonfirmasi eksplisit bahwa perubahan siap ke production.
- Selalu buat **branch baru** buat tiap fitur/perubahan, jangan langsung commit ke `main`.
- Kalau ragu soal keputusan produk/fitur yang belum jelas di dokumen ini, **tanya dulu ke Reno**, jangan asumsi sendiri — terutama buat hal yang menyentuh data finansial user (perhitungan budget, kategori wajib/keinginan, dll).
- Ikuti tone & terminology yang udah ditetapkan di bagian **6. Voice & Terminology Guide** — jangan pakai bahasa formal/korporat di UI atau microcopy manapun.
- Scope fitur mengikuti pembagian **V1 vs V2+** di bagian 4 & 5 — jangan menambah fitur di luar scope V1 tanpa dikonfirmasi dulu, biar nggak scope creep.

---

## 1. Overview

- **Nama app**: **KIRAIN** (stylization: huruf kapital semua)
- **Nama lengkap**: "Kirain - Asisten Keuanganmu"
- **Jenis proyek**: Side project pribadi, terpisah total dari GENSITI. Tujuan: belajar, having fun, portofolio, potensi side income jangka panjang.
- **Developer**: Solo dev (Reno), dikerjain di sela kerja (karyawan swasta, UMR) + kuliah.
- **Platform awal**: Native mobile Android (Play Store + Galaxy Store). iOS/App Store bisa nyusul kalau Flutter dipakai (cross-platform).

---

## 2. Brand & Positioning

**Insight/pain point awal:**
Anak muda (Gen Z/Milenial) sering susah bedain kebutuhan wajib vs keinginan, dan susah konsisten nyatet keuangan karena tergantung mood/effort tinggi di app finance kebanyakan.

**Diferensiasi utama:**
Bukan sekadar pencatat transaksi (red ocean market — udah banyak Money Lover, Monefy, Spendee, PINA, dll), tapi **"decision layer"** — bantu user mikir sebelum belanja, bukan cuma nyatet setelahnya.

**Persona/Karakter app:**
- **Asisten** — bukan "temen deket" yang usil terus, bukan juga "aplikasi korporat" yang kaku
- **Tone: "santai yang serius pas dibutuhkan"**
  - Kondisi normal → santai, kadang bercanda dikit
  - Kondisi warning (mendekati limit) → netral-informatif, mulai gak lucu-lucuan
  - Kondisi kritis (defisit/mau checkout padahal wajib belum kepenuhi) → jelas & langsung, tapi tetap gak nge-judge
- **Budaya**: mix — netral secara default (universal, gak eksklusif), dengan sentuhan lokal/islami yang nyempil natural (infak/zakat sebagai kategori wajib, peringatan riba, dll), bukan dominan terus-menerus

**Target user:**
Awalnya komunitas Generus (unfair advantage: distribusi & trust), tapi didesain **universal** — gak dibatasi status pernikahan, umur, atau circle tertentu. Kalau responnya bagus, siap di-scale ke luar.

**Tagline (draft, belum final):**
- "Kirain cukup, taunya boncos."
- "Biar gak kirain-kirain lagi."
- "Sebelum kirain, cek dulu."

**Nama untuk App Store listing:**
"Kirain - Asisten Keuanganmu"

---

## 3. Arsitektur Teknis

### Stack
- **Frontend**: Flutter (native mobile, cross-platform siap kalau mau ke iOS nanti)
- **Backend**: Supabase — **project baru, terpisah total dari GENSITI**
- **Auth**: Supabase Auth (pertimbangkan magic link/OTP biar lebih ramah buat user awam, dibanding password)

### Model Data: Cloud-Primary + Local Write-Ahead Queue
> **PENTING**: Ini BUKAN local-first murni (ala WhatsApp dengan sync 2 arah). Ini juga bukan pure cloud-first tanpa buffer.

- **Supabase = source of truth utama**
- **Local queue/cache ringan** dipakai HANYA sebagai buffer kondisi offline:
  - Transaksi yang gagal terkirim (gak ada internet) disimpen dulu di antrian lokal
  - Auto-retry & auto-kirim begitu koneksi balik online
  - User tetap lihat transaksinya "tercatat" di UI dengan indikator kecil "belum tersinkron"
- **TIDAK ADA** conflict resolution kompleks / bidirectional sync — karena cloud tetap 1 sumber kebenaran
- Reinstall/ganti HP: otomatis balik normal setelah login ulang (data di cloud, gak perlu restore manual)

### Keamanan Development (Staging vs Production)
> **Belum final — 2 opsi didiskusikan, pilih salah satu atau kombinasi sebelum mulai coding:**
1. Project Supabase kedua khusus dev/testing (`kirain-dev` terpisah dari `kirain-prod`) — paling aman, effort kecil (gratis di tier Free)
2. PR + CI/CD gate di GitHub (migration hanya jalan otomatis setelah merge ke `main`, gak pernah manual ke production) — cukup aman buat human error, tapi TIDAK melindungi dari kesalahan desain skema yang baru ketahuan setelah kena production

**Rekomendasi:** kombinasi keduanya kalau memungkinkan, minimal salah satu HARUS ada (jangan ulangi insiden migration GENSITI).

### Requirement Teknis Lain
- **Minimum Android**: 8.0 Oreo (API 26)
- **Target ukuran APK**: di bawah 30–50MB
- **Performance**: lazy loading riwayat transaksi (jangan load semua sekaligus), compress asset
- **Crash monitoring**: Firebase Crashlytics (gratis, ringan, integrasi gampang di Flutter)
- **Notification channels** (Android): dipisah jadi "Reminder Harian", "Peringatan Budget", "Update & Info" — biar user bisa matiin sebagian tanpa matiin semua

### Pola yang Bisa "Dipelajari Ulang" dari GENSITI
- Pattern RLS (row-level security) — disederhanakan karena KIRAIN cuma butuh per-user isolation, gak perlu role-based setingkat GENSITI
- RPC functions (Postgres) buat kalkulasi kompleks (total wajib/keinginan) — di database layer, bukan di client
- Kebiasaan dokumentasi terstruktur (CLAUDE.md-style) dari awal proyek
- Guardrail migration dari pelajaran insiden GENSITI

---

## 4. Fitur — Scope V1 (Rilis Pertama)

### Core / Wajib Ada
- [ ] **Quick-add transaksi** — 2-3 tap, minimal friction
- [ ] **Toggle Wajib vs Keinginan** di tiap transaksi (fitur diferensiasi utama)
- [ ] **Income tracking** — kategori: Gaji, Freelance/Sampingan, THR/Bonus, Lainnya (fondasi kalkulasi wajib/keinginan)
- [ ] **Dashboard** — progress bar visual sisa budget wajib vs keinginan
- [ ] **Kategori custom** (user bisa tambah/edit/hapus), default kategori di bawah
- [ ] **Riwayat transaksi** dengan **search & filter** (kategori, range tanggal, teks catatan)
- [ ] **Catatan teks bebas** di tiap transaksi (foto struk ditunda ke v2)
- [ ] **Siklus budget custom** — user set tanggal mulai siklus (bukan cuma tanggal 1)
- [ ] **Budget rollover** — default carry-over ke bulan depan, ada toggle buat matiin
- [ ] **Budget alert per kategori** — threshold default 80%, bisa custom per kategori
- [ ] **Transaksi berulang / recurring** — termasuk cicilan (masuk kategori Wajib otomatis)
- [ ] **Deteksi transaksi duplikat** — soft warning, bukan blocking
- [ ] **Batch entry ringan** — tombol "Tambah Lagi" setelah nyatet, tanpa balik ke home
- [ ] **Target Nabung / savings goal** — termasuk Dana Darurat sebagai salah satu jenis target (bukan kategori struktural terpisah)
- [ ] **Multiple goal prioritization** — drag-reorder urutan prioritas target
- [ ] **Perbandingan antar periode** — indikator simpel "naik/turun X% dari bulan lalu"
- [ ] **Transparansi perhitungan** — breakdown yang bisa di-expand/tap, bukan black box
- [ ] **Auto-collapse kategori kosong** — kategori yang belum pernah dipakai disembunyikan dari list utama
- [ ] **Handling saldo negatif** — tampil jelas (warna merah) tapi tone tetap suportif, gak menghakimi
- [ ] **Peringatan riba/paylater** — soft notice kontekstual (bukan sistem deteksi otomatis agresif), edukatif bukan menghakimi
- [ ] **Tips edukasi finansial ringan** — 1 tips random per kunjungan Home, konten ditulis manual (20-30 tips), bisa di-dismiss
- [ ] **Reminder kontekstual gajian** — notif pas masuk siklus budget baru, ajak alokasi ke Target dulu
- [ ] **Retroactive entry** — opsi isi transaksi dari awal bulan pas onboarding pertama kali (biar rekap gak "kepotong")

### UX & Onboarding
- [ ] Onboarding maksimal 3 layar, ada opsi **Skip**
- [ ] Empty state yang "hidup" (microcopy + CTA jelas, bukan layar kosong)
- [ ] Loading state pakai skeleton screen (bukan spinner polos)
- [ ] Error state jelas + actionable (tombol retry, bahasa sesuai brand, hindari jargon teknis)
- [ ] Splash screen simpel (logo + nama, durasi singkat)
- [ ] Bottom navigation 4 tab: **Home / Catat / Rekap / Kamu**
- [ ] Dark mode (v1, bukan nyusul)
- [ ] App shortcuts — long-press icon langsung ke "Catat Transaksi"
- [ ] Widget home screen — ringkasan sisa budget + quick-add
- [ ] FAQ/Help Center sederhana di dalam app (statis)
- [ ] Aksesibilitas dasar: kontras warna cukup, tap target min 48x48dp, font ngikut sistem device

### Keamanan & Privasi
- [ ] App lock — biometric (default kalau device support) + PIN (fallback)
- [ ] Hapus akun & data — self-service dari halaman Profil, bukan cuma via kontak manual
- [ ] Privacy Policy (data gak dikirim ke pihak ketiga selain Supabase sebagai processor)
- [ ] Terms of Service (lihat bagian 7)
- [ ] Google Play Data Safety form — disiapkan jujur & jelas sebelum submit

### Data & Export
- [ ] Export **CSV** (prioritas utama v1)
- [ ] Export PDF — nice-to-have, nyusul kalau CSV udah beres duluan

### Support
- [ ] Channel support: **WA Bisnis** + **email**
- [ ] Grup WA kecil khusus beta tester (5-10 orang dari circle Generus), terpisah dari WA Bisnis support resmi

### Kategori Default

**Wajib:**
Makan & Minum · Transportasi · Tempat Tinggal · Tagihan (listrik/air/internet/pulsa) · Infak/Zakat · Kesehatan

**Keinginan:**
Jajan & Nongkrong · Hiburan · Belanja · Hobi

**Pemasukan:**
Gaji · Freelance/Sampingan · THR/Bonus · Lainnya

---

## 5. Fitur — Roadmap Setelah V1

### v1.1 (effort kecil-menengah, impact tinggi)
- Export PDF
- Foto struk di transaksi

### v1.2
- Kalender musiman (Ramadan/Lebaran) — konten kontekstual pengeluaran
- Import data CSV dari sumber lain (Excel/app lain)

### v1.3
- Mode "berdua" / shared budget (siapkan konsep schema dari awal, misal `household_id`, walau fitur baru dieksekusi di sini)
- Audit trail edit transaksi (relevan begitu shared budget ada)

### v2.0+
- **"KIRAIN Wrapped"** — recap tahunan ala Spotify Wrapped, shareable ke sosmed (growth channel)
- Interaksi sosial ringan (jumlah user komunitas yang pakai KIRAIN, tanpa expose data personal)
- Ringkasan berkala otomatis via WhatsApp Business API (butuh setup provider pihak ketiga)
- Shortcut power user — quick parse text natural language ("50rb makan" auto jadi transaksi)
- Siklus akademik/semester khusus (niche buat mahasiswa)
- Sync multi-device dengan UI manajemen sesi eksplisit (kalau ternyata dibutuhkan)

---

## 6. Voice & Terminology Guide

**Prinsip umum:** hindari bahasa formal/korporat di SEMUA touchpoint, termasuk yang kecil (tombol, konfirmasi, error).

| Elemen | Istilah |
|---|---|
| Tombol tambah transaksi | **Catat** |
| Tombol simpan | **Oke, Catat** |
| Halaman pengaturan | **Pengaturan Kamu** |
| Halaman profil | **Kamu** |
| Konfirmasi hapus | **Yakin nih?** |
| Fitur laporan/insight | **Rekap Kirain** / **Cerita Bulan Ini** |
| Sisa budget aman | **Zona Aman** |
| Budget udah abis/lewat | **Zona Kirain** |
| Progress budget wajib | **Progress Cukup** |

**Contoh microcopy:**
- Empty state: *"Belum ada catatan nih. Yuk mulai dari transaksi pertama, biar gak kirain-kirain lagi 👀"*
- Defisit/saldo negatif: *"Bulan ini kebablasan nih, gapapa. Yuk kita rapiin lagi bulan depan 💪"*
- Warning budget wajib belum kepenuhi: *"Eh tunggu, kebutuhan wajib bulan ini belum full nih. Yakin mau checkout?"*
- Reminder gajian: *"Gajian nih? Yuk alokasiin ke Target Nabung dulu sebelum kepake buat yang lain 💰"*
- Peringatan riba: *"Eh, ini kedengerannya kayak transaksi berbunga (riba) ya? Yuk coba dipikir ulang, atau kalau emang udah jalan, yuk kita bantu lunasin secepatnya 🙏"*
- Error koneksi: *"Yah, KIRAIN lagi susah connect nih. Coba cek internet kamu, atau tunggu bentar ya 🔌"*
- Transaksi offline queue: *"Transaksi kamu ke-antri dulu ya, nanti otomatis kesimpen begitu online lagi"*

**Format nominal:**
- Dashboard/ringkasan → disingkat ("Rp 1,5jt")
- Riwayat/detail transaksi → penuh ("Rp 1.500.000")

---

## 7. Legal — Poin Terms of Service

1. Deskripsi layanan — KIRAIN adalah alat bantu pencatatan pribadi, BUKAN layanan finansial berlisensi/bank/e-wallet
2. Syarat akun pengguna (umur minimal, tanggung jawab keamanan login)
3. Kepemilikan data — data transaksi tetap milik user
4. Batasan tanggung jawab (disclaimer) — KIRAIN bukan penasihat keuangan resmi, bukan bertanggung jawab atas keputusan finansial user
5. Larangan penyalahgunaan (reverse engineering, aktivitas ilegal, dll)
6. Hak perubahan layanan sepihak
7. Kondisi penghentian/suspend akun
8. Kontak & penyelesaian sengketa (arahkan ke WA/email support)

---

## 8. Personal Branding

- Halaman "Tentang" di dalam app menampilkan nama developer secara personal (bukan brand korporat anonim), contoh: *"Kirain dibuat oleh Reno, developer solo yang juga lagi belajar ngatur duit sendiri 😄"*
- Opsional: link portofolio/LinkedIn/GitHub

---

## 9. Testing & Launch Plan

- **Device testing**: OPPO A3s (Android 8.1 — lower bound), device pribadi (higher-end/foldable — Galaxy Z Flip5) + emulator Android Studio buat gap versi di tengah
- **Beta testing**: grup WA kecil (5-10 orang circle Generus), fokus feedback ke 2 hal: kemudahan nyatet transaksi & kepakean toggle wajib/keinginan
- **Rating prompt**: munculin setelah milestone positif (misal 14 hari konsisten nyatet), pakai Google In-App Review API — jangan di hari pertama install
- **Testimoni**: kumpulin dari beta tester setelah 2-3 minggu pakai, izin quote (nama depan/anonim), simpan buat listing/promosi

### App Store Listing
- **Nama**: Kirain - Asisten Keuanganmu
- **Screenshot** (urutan): Dashboard progress wajib/keinginan → Quick-add → Rekap/insight bulanan → Fitur keamanan (PIN/biometric) → Dark mode
- **ASO keywords**: aplikasi keuangan, catatan pengeluaran, atur keuangan, budgeting, kelola uang, financial planner, money tracker, kebutuhan vs keinginan, asisten keuangan

---

## 10. Post-Launch Iteration Plan

**Prioritas feedback:**
1. Bug/crash → prioritas tertinggi (trust data finansial)
2. UX friction → prioritas kedua (menyerang value inti "kemudahan")
3. Feature request → dikumpulin dulu, cari pola sebelum dieksekusi

**Proses:** feedback masuk lewat WA/email → dicatat manual (Notion/Sheet) → direview & diprioritaskan pas ada waktu luang (weekend) → rilis update kecil berkala (gak perlu jadwal ketat, yang penting app terasa "hidup & diurus").

---

## 11. Hal yang Sengaja TIDAK Dimasukkan ke V1

- Multi-currency (full Rupiah dulu)
- Onboarding quiz/personality
- Voice input / scan struk otomatis / baca notifikasi bank-ewallet otomatis
- Sistem referral dengan reward (cukup tombol share sederhana)
- Analytics kompleks (kalau perlu, minimal event tracking privacy-friendly via Firebase)
- Fitur khusus siklus akademik/semester

---

*Dokumen ini adalah rangkuman brainstorming, bukan spek final yang gak bisa berubah — tetap fleksibel disesuaikan pas eksekusi berjalan.*
