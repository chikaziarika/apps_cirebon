// =========================================================
// FUNGSI EKSPOR MODAL KE PDF (DENGAN HALAMAN LAMPIRAN FOTO)
// =========================================================
function unduhDetailPDF(tipe) {
    let modalId = tipe === 'saluran' ? 'modalSaluranDetail' : 'modalAsetDetail'; 
    let originalElement = document.querySelector(`#${modalId} .modal-content`);

    if (!originalElement) {
        alert("Gagal memproses PDF: Tampilan detail tidak ditemukan.");
        return;
    }

    // 1. KLONING ELEMEN (Agar UI asli di layar tidak ikut berubah/rusak)
    let clone = originalElement.cloneNode(true);

    // 2. BERSIHKAN TOMBOL DI PDF
    clone.querySelectorAll('button, .btn-close, .btn-download-pdf').forEach(btn => btn.remove());

    // 3. SIAPKAN HALAMAN BARU KHUSUS FOTO
    // Membuat div dengan class bawaan html2pdf untuk memaksa ganti halaman
    let pageBreak = document.createElement('div');
    pageBreak.classList.add('html2pdf__page-break');

    let fotoSection = document.createElement('div');
    fotoSection.innerHTML = '<h4 style="margin-top: 20px; font-weight: bold; border-bottom: 2px solid #0d3b66; padding-bottom: 10px; color: #0d3b66;">LAMPIRAN DOKUMENTASI</h4>';
    
    // PERBAIKAN: Gunakan text-align center biasa, HINDARI flexbox agar tidak terpotong di PDF
    let galleryContainer = document.createElement('div');
    galleryContainer.style.textAlign = 'center'; 
    galleryContainer.style.marginTop = '20px';

    let hasImages = false;

    // 4. CABUT SEMUA GAMBAR DARI TABEL & PINDAHKAN KE HALAMAN BARU
    let images = clone.querySelectorAll('img');
    images.forEach(img => {
        // Abaikan icon, logo, atau gambar yang sangat kecil
        if (img.src.includes('Logo') || img.src.includes('icon') || img.width < 50) return;

        hasImages = true;

        // PERBAIKAN UTAMA: Bungkus tiap foto dengan div khusus anti-potong
        let imgWrapper = document.createElement('div');
        imgWrapper.style.pageBreakInside = 'avoid'; // Perintah khusus untuk cetak PDF
        imgWrapper.style.breakInside = 'avoid';     // Perintah khusus untuk cetak PDF
        imgWrapper.style.display = 'inline-block';
        imgWrapper.style.margin = '10px';
        imgWrapper.style.verticalAlign = 'top';

        // Cetak ulang gambar dengan ukuran proporsional
        let newImg = document.createElement('img');
        newImg.src = img.src;
        newImg.style.width = '320px'; 
        newImg.style.height = '220px';
        newImg.style.objectFit = 'cover';
        newImg.style.borderRadius = '8px';
        newImg.style.border = '2px solid #ddd';

        imgWrapper.appendChild(newImg);
        galleryContainer.appendChild(imgWrapper);

        // Hapus gambar asli dari baris tabel (beserta wadahnya) agar tabel jadi ringkas
        if (img.closest('.sal-gallery-item')) {
            img.closest('.sal-gallery-item').remove();
        } else if (img.closest('.photo-card')) {
            img.closest('.photo-card').remove();
        } else {
            img.remove();
        }
    });

    // 5. BERSIHKAN TEKS "TIDAK ADA FOTO" DI TABEL
    clone.querySelectorAll('.text-muted, .small').forEach(el => {
        if (el.innerText.includes('Tidak ada foto') || el.innerText.includes('Foto belum tersedia')) {
            el.remove();
        }
    });

    // 6. GABUNGKAN HALAMAN FOTO JIKA ADA FOTONYA
    if (hasImages) {
        fotoSection.appendChild(galleryContainer);
        clone.appendChild(pageBreak); // Paksa halaman ke-2
        clone.appendChild(fotoSection);
    }

    // 7. SETTING & EKSEKUSI PDF
    let rawName = tipe === 'saluran' ? $('#sal-nama').text() : $('#det-nomenklatur_ruas').text() || 'Aset_Bangunan';
    let namaFile = rawName.replace(/[^a-zA-Z0-9]/g, '_'); 
    
    var opt = {
        margin:       0.4, 
        filename:     `Laporan_Detail_${tipe}_${namaFile}.pdf`,
        image:        { type: 'jpeg', quality: 0.98 },
        html2canvas:  { scale: 2, useCORS: true, scrollY: 0 },
        jsPDF:        { unit: 'in', format: 'a4', orientation: 'portrait' },
        // PERBAIKAN: Tambahkan 'avoid-all' agar PDF memaksa elemen tidak terpotong
        pagebreak:    { mode: ['avoid-all', 'css', 'legacy'] } 
    };

    // Render dari elemen 'clone'
    html2pdf().set(opt).from(clone).save();
}