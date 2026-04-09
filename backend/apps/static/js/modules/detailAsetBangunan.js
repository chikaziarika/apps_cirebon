function bukaModalDetailAset(response) {
    console.log("Response diterima:", response);

    // 1. Ekstraksi data dari properti "data" (Array)
    let data = null;
    if (response && response.data && Array.isArray(response.data) && response.data.length > 0) {
        data = response.data[0]; // Mengambil objek pertama dari array data
    } else if (response && !response.data) {
        data = Array.isArray(response) ? response[0] : response;
    }

    // Validasi apakah data berhasil diambil
    if (!data || typeof data !== 'object' || Object.keys(data).length === 0) {
        console.error("Data tidak ditemukan dalam response API. Isi response:", response);
        alert("Maaf, detail data bangunan ini belum tersedia di database.");
        return;
    }

    // Fungsi pembantu untuk set teks ke elemen HTML
    const safeSet = (id, val) => {
        const el = document.getElementById(id);
        // Gunakan innerHTML agar bisa merender elemen HTML (misal <span> badge)
        if (el) el.innerHTML = (val !== null && val !== undefined && val !== "") ? val : "-"; 
    };

    // 2. Mapping Section I: IDENTITAS & LOKASI
    safeSet('pai-nama-header', data.nama_aset_manual);
    safeSet('pai-nama-aset', data.nama_aset_manual);
    safeSet('pai-nomenklatur', data.nomenklatur_ruas); 
    
    let kodeAset = data.kode_aset_display || data.kode_aset || "-";
    safeSet('pai-jenis', kodeAset);
    
    safeSet('pai-di-nama', data.nama_di);
    safeSet('pai-saluran-nama', data.nama_saluran);
    safeSet('pai-surveyor', data.surveyor);
    safeSet('pai-desa', data.desa);
    safeSet('pai-kec', data.kecamatan);

    // 👇 LOGIKA KONDISI ASET DENGAN BADGE 👇
    let kondisi = data.kondisi_bangunan || data.kondisi_aset || "BAIK";
    let badgeClass = 'bg-success';
    let kUpper = kondisi.toUpperCase();

    if (kUpper.includes('RR') || kUpper.includes('RINGAN') || kUpper.includes('SEDANG')) badgeClass = 'bg-warning text-dark';
    if (kUpper.includes('RB') || kUpper.includes('BERAT')) badgeClass = 'bg-danger';
    if (kUpper.includes('BAP') || kUpper.includes('PASANGAN')) badgeClass = 'bg-secondary';
    
    safeSet('pai-kondisi-aset', `<span class="badge ${badgeClass}">${kUpper}</span>`);

    // 3. Mapping Section II: NOMENKLATUR & LUAS LAYANAN
    safeSet('pai-nom-kiri', data.saluran_manual_kiri || data.nomenklatur_kiri);
    safeSet('pai-jenis-kiri', data.jenis_saluran_kiri);
    safeSet('pai-luas-kiri', data.luas_kiri);

    safeSet('pai-nom-tengah', data.saluran_manual_tengah || data.nomenklatur_tengah);
    safeSet('pai-jenis-tengah', data.jenis_saluran_tengah);
    safeSet('pai-luas-tengah', data.luas_tengah);

    safeSet('pai-nom-kanan', data.saluran_manual_kanan || data.nomenklatur_kanan);
    safeSet('pai-jenis-kanan', data.jenis_saluran_kanan);
    safeSet('pai-luas-kanan', data.luas_kanan);

    safeSet('pai-luas-total', data.luas_areal);

    // 4. Mapping Section III: DATA TEKNIS
    safeSet('pai-lebar', data.lebar_saluran);
    safeSet('pai-tinggi', data.tinggi_saluran);
    
    // 👇 LOGIKA PERHITUNGAN PINTU 👇
    // 👇 LOGIKA PERHITUNGAN PINTU & RENDER KARTU PINTU 👇
    let totalPintu = parseInt(data.pintu_total_unit) || 0;
    let bPintu = parseInt(data.pintu_baik) || 0;
    let rrPintu = parseInt(data.pintu_rusak_ringan) || 0;
    let rbPintu = parseInt(data.pintu_rusak_berat) || 0;
    
    const containerPintu = document.getElementById('pai-daftar-pintu');
    
    // 🔥 JURUS ANTI GAGAL: Tangkap pintu_list ATAU unit_pintu 🔥
    let daftarPintu = data.pintu_list || data.unit_pintu;

    if (daftarPintu && daftarPintu.length > 0) {
        totalPintu = daftarPintu.length;
        bPintu = 0; rrPintu = 0; rbPintu = 0;
        
        let pintuHtml = daftarPintu.map(p => {
            let pk = (p.kondisi || "BAIK").toUpperCase();
            let pBadge = 'bg-success';
            
            if (pk === 'BAIK') bPintu++;
            else if (pk === 'RR' || pk.includes('RINGAN')) { rrPintu++; pBadge = 'bg-warning text-dark'; pk = 'R. RINGAN'; }
            else if (pk === 'RB' || pk.includes('BERAT')) { rbPintu++; pBadge = 'bg-danger'; pk = 'R. BERAT'; }

            // TANGKAP URL FOTO DARI SERIALIZER
            let fotoUrl = p.foto_pintu_url || p.foto_pintu || null; 
            
            let imgTag = fotoUrl
                ? `<a href="${fotoUrl}" target="_blank"><img src="${fotoUrl}" class="img-thumbnail mt-1 shadow-sm" style="width: 100%; height: 90px; object-fit: cover; border-radius: 4px;"></a>`
                : `<div class="bg-white text-muted border text-center mt-1 d-flex flex-column justify-content-center" style="width: 100%; height: 90px; font-size: 10px; border-radius: 4px;"><i class="fa-solid fa-image-slash fs-4 mb-1"></i>No Photo</div>`;

            return `
            <div class="col-md-3 col-sm-4 col-6">
                <div class="card border-0 shadow-sm h-100" style="background-color: #fff;">
                    <div class="card-body p-2 text-center d-flex flex-column">
                        <b class="text-primary text-truncate mb-1" style="font-size: 0.75rem;" title="${p.nama_pintu || '-'}">${p.nama_pintu || '-'}</b>
                        <span class="badge ${pBadge} mb-1 align-self-center" style="font-size: 0.6rem; min-width: 50px;">${pk}</span>
                        <div class="text-muted mb-1" style="font-size: 0.65rem;"><i class="fa-solid fa-ruler-combined"></i> ${p.lebar_pintu || 0} x ${p.tinggi_pintu || 0} m</div>
                        <div class="mt-auto">
                            ${imgTag}
                        </div>
                    </div>
                </div>
            </div>`;
        }).join('');
        
        if (containerPintu) containerPintu.innerHTML = pintuHtml;
        
    } else {
        if (containerPintu) containerPintu.innerHTML = '<div class="col-12 text-center p-3"><span class="text-muted small"><i class="fa-solid fa-door-closed me-1"></i> Tidak ada rincian unit pintu untuk bangunan ini.</span></div>';
    }
    
    safeSet('pai-pintu-lengkap', `Total: ${totalPintu} (B:${bPintu}, RR:${rrPintu}, RB:${rbPintu})`);
    
    // Asumsi default cabang 0 jika tidak ada data spesifik di API
    safeSet('pai-cab-sek', 0);
    safeSet('pai-cab-ter', 0);

    // Koordinat Geometri
    const lat = data.latitude !== undefined && data.latitude !== null ? data.latitude : "-";
    const lng = data.longitude !== undefined && data.longitude !== null ? data.longitude : "-";
    safeSet('pai-geometri', `${lat}, ${lng}`);
    safeSet('pai-catatan', data.keterangan || "-");

    // 5. Mapping Section IV: DOKUMENTASI (Galeri Foto)
    const containerFoto = document.getElementById('pai-foto-galeri');
    if (containerFoto) {
        let photos = data.all_photos || [];
        if (photos.length > 0) {
            containerFoto.innerHTML = photos.map(url => `
                <div class="sal-gallery-item" style="display: inline-block; margin-right: 10px; margin-bottom: 10px;">
                    <a href="${url}" target="_blank">
                        <img src="${url}" class="img-thumbnail" style="width: 120px; height: 100px; object-fit: cover;">
                    </a>
                </div>
            `).join('');
        } else {
            containerFoto.innerHTML = '<span class="text-muted small">Tidak ada foto dokumentasi</span>';
        }
    }

    // 6. Eksekusi Tampilkan Modal
    const modalEl = document.getElementById('modalAsetDetail');
    if (modalEl) {
        const myModal = bootstrap.Modal.getOrCreateInstance(modalEl);
        myModal.show();
        
        // Pindahkan ke tab PAI secara otomatis
        const tabPAI = document.querySelector('button[data-bs-target="#tab-pai"]');
        if (tabPAI) bootstrap.Tab.getOrCreateInstance(tabPAI).show();
    }
}