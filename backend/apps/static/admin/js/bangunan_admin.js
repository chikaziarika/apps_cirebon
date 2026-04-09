

document.addEventListener('change', function(e) {
    // Mengecek apakah yang diubah adalah dropdown Poligon Layanan (pada form inline)
    if (e.target && e.target.id.endsWith('-poligon_layanan')) {
        const layerId = e.target.value;
        
        // Cari elemen pembungkus terdekat (biasanya fieldset atau div.form-row)
        const container = e.target.closest('fieldset') || e.target.closest('.form-row');
        
        // Cari input Luas Areal yang spesifik di dalam pembungkus yang sama
        const luasInput = container.querySelector('input[id$="-luas_areal"]');

        if (layerId) {
            // Panggil API yang baru saja kita buat
            fetch(`/admin/apps/bangunan/get-poligon-luas/${layerId}/`)
                .then(response => response.json())
                .then(data => {
                    if (luasInput && data.luas_areal !== undefined) {
                        luasInput.value = data.luas_areal;
                        
                        // Opsional: Beri efek visual singkat agar admin tahu data berubah otomatis
                        luasInput.style.backgroundColor = '#d4edda'; // Warna hijau muda
                        setTimeout(() => { luasInput.style.backgroundColor = ''; }, 1500);
                        
                        console.log(`Luas diupdate otomatis: ${data.luas_areal} Ha`);
                    }
                })
                .catch(err => console.error("Gagal mengambil data luas poligon:", err));
        } else {
            // Jika dropdown di-clear/dikosongkan, kembalikan ke 0
            if (luasInput) luasInput.value = 0;
        }
    }
});

document.addEventListener('change', function(e) {
    if (e.target.id === 'id_daerah_irigasi') { // Sesuaikan ID dropdown DI
        const diId = e.target.value;
        if (diId) {
            fetch(`/get-di-stats/${diId}/`)
                .then(response => response.json())
                .then(data => {
                    // Isi field luas fungsional secara otomatis
                    const luasField = document.querySelector('#id_luas_fungsional');
                    if (luasField) luasField.value = data.total_luas;
                });
        }
    }
});

document.addEventListener('change', function(e) {
    // Cek apakah yang diubah adalah dropdown Kode Aset
    if (e.target && e.target.name && e.target.name.includes('kode_aset')) {
        const kode = e.target.value;
        // Cari input Nama Aset yang satu baris dengan dropdown ini
        const row = e.target.closest('.form-row') || e.target.closest('fieldset');
        const namaInput = row.querySelector('input[name*="nama_aset_manual"]');


        const kamusAset = {
        // --- BANGUNAN UTAMA & PENGATUR (B & P) ---
        'B01': 'Bendung',
        'B02': 'Bendung Gerak',
        'B03': 'Bendung Karet',
        'B04': 'Pengambilan Bebas',
        'B05': 'Pompa',
        'B06': 'Waduk / Embung',
        'B07': 'Kantong Lumpur',
        'P01': 'Bangunan Bagi',
        'P02': 'Bangunan Bagi Sadap',
        'P03': 'Bangunan Sadap',
        'P04': 'Bangunan Pengatur',

        // --- SALURAN (S) ---
        'S01': 'Saluran Primer',
        'S02': 'Saluran Sekunder',
        'S03': 'Saluran Suplesi',
        'S04': 'Saluran Muka',
        'S11': 'Saluran Pembuang',
        'S12': 'Saluran Gendong',
        'S13': 'Saluran Pengelak Banjir',
        'S15': 'Saluran Tersier',
        'S16': 'Saluran Kuarter',
        'S17': 'Saluran Pembuang (Tersier)',

        // --- BANGUNAN PENGUKUR & PELENGKAP (C, K, D, dsb) ---
        'C01': 'Alat Ukur Ambang Lebar',
        'C02': 'Alat Ukur Parshall Flume',
        'C03': 'Alat Ukur Cipoletti',
        'C04': 'Alat Ukur Thompson',
        'C05': 'Alat Ukur Romijn',
        'K01': 'Bangunan Terjun',
        'K02': 'Got Miring',
        'K03': 'Siphon',
        'K04': 'Talud',
        'K05': 'Flume',
        'K06': 'Terowongan',
        'D01': 'Pintu Air',
        'D02': 'Pintu Sorong',
        'D03': 'Pintu Klep',
        'L01': 'Jembatan',
        'L02': 'Gorong-gorong',
        'L03': 'Bangunan Cuci / Mandi',
        'L04': 'Tempat Menyeberang Ternak',
        'L05': 'Tangga Manusia'
    };

        if (namaInput && kamusAset[kode]) {
            namaInput.value = kamusAset[kode];
        }
    }
});

(function($) {
    $(document).ready(function() {
        
        // =================================================================
        // FUNGSI 1: KOREKSI DATA LAMA SAAT HALAMAN DIBUKA (Untuk Pintu)
        // =================================================================
        function perbaikiDataLama() {
            var nomRuas = $('#id_nomenklatur_ruas').val();
            if (nomRuas) {
                $('input[name$="-nama_pintu"]').each(function() {
                    var currVal = $(this).val().trim();
                    if (currVal !== "" && !isNaN(currVal)) {
                        $(this).val(nomRuas + ' - Pintu ' + currVal);
                        $(this).css({ 'background-color': '#fff3cd' }); 
                    }
                });
            }
        }
        setTimeout(perbaikiDataLama, 500);

        // =================================================================
        // FUNGSI 2: AUTO-FILL SAAT TOMBOL "Add another Unit Pintu" DIKLIK
        // =================================================================
        $(document).on('click', '.add-row a', function() {
            var nomRuas = $('#id_nomenklatur_ruas').val();
            if (nomRuas) {
                setTimeout(function() {
                    $('input[name$="-nama_pintu"]').each(function() {
                        if ($(this).val() === "") {
                            $(this).val(nomRuas + ' - Pintu ');
                            
                            var $input = $(this);
                            $input.css({ 'background-color': '#e8f4f8', 'transition': 'background-color 0.5s ease' });
                            setTimeout(function() { $input.css('background-color', ''); }, 1500);
                        }
                    });
                }, 100);
            }
        });

        // =================================================================
        // FUNGSI 3: AUTO-FILL NOMENKLATUR PERCABANGAN SAAT DIKLIK (Kiri/Tengah/Kanan)
        // =================================================================
        function setupAutoFillPercabangan() {
            var targetBranches = [
                { selector: 'input[name$="-nomenklatur_kiri"]', suffix: ' - Kiri' },
                { selector: 'input[name$="-nomenklatur_tengah"]', suffix: ' - Tengah' },
                { selector: 'input[name$="-nomenklatur_kanan"]', suffix: ' - Kanan' }
            ];

            targetBranches.forEach(function(target) {
                // Gunakan event 'focus' agar saat admin mengeklik kotak kosong, langsung terisi
                $(document).on('focus', target.selector, function() {
                    var nomRuas = $('#id_nomenklatur_ruas').val();
                    
                    if (nomRuas && $(this).val() === "") {
                        $(this).val(nomRuas + target.suffix);
                        
                        var $input = $(this);
                        $input.css({ 'background-color': '#e8f4f8', 'transition': '0.5s' });
                        setTimeout(function() { $input.css('background-color', ''); }, 1500);
                    }
                });
            });
        }
        setupAutoFillPercabangan();
        
        // =================================================================
        // FUNGSI 4: UPDATE OTOMATIS MASSAL JIKA NOMENKLATUR INDUK DIKETIK ULANG
        // =================================================================
        $('#id_nomenklatur_ruas').on('input', function() {
            var nomRuasBaru = $(this).val();
            
            // A. Update semua Nama Pintu
            $('input[name$="-nama_pintu"]').each(function() {
                var valLama = $(this).val();
                if (valLama.includes(' - Pintu ')) {
                    var parts = valLama.split(' - Pintu ');
                    if (parts.length > 1) {
                        $(this).val(nomRuasBaru + ' - Pintu ' + parts[1]);
                    }
                } else if (valLama.includes(' - ')) {
                    // Berjaga-jaga jika formatnya "Nomenklatur - Kiri"
                    var parts = valLama.split(' - ');
                    if (parts.length > 1) {
                        $(this).val(nomRuasBaru + ' - ' + parts[1]);
                    }
                }
            });

            // B. Update semua Nomenklatur Percabangan
            var branchSuffixes = [' - Kiri', ' - Tengah', ' - Kanan'];
            var branchSelectors = [
                'input[name$="-nomenklatur_kiri"]', 
                'input[name$="-nomenklatur_tengah"]', 
                'input[name$="-nomenklatur_kanan"]'
            ];

            branchSelectors.forEach(function(selector, idx) {
                $(selector).each(function() {
                    var valLama = $(this).val();
                    var currentSuffix = branchSuffixes[idx];
                    
                    // Hanya timpa jika teks sebelumnya memang berakhiran " - Kiri/Tengah/Kanan"
                    // (Mencegah kita merusak data jika admin sudah mengetik nama custom)
                    if (valLama !== "" && valLama.endsWith(currentSuffix)) {
                        $(this).val(nomRuasBaru + currentSuffix);
                    }
                });
            });
        });

        $('form').on('submit', function(e) {
            let isFormValid = true;
            let firstInvalidField = null;

            // Cek semua input yang memiliki atribut 'required' di dalam form ini
            $(this).find('input[required], select[required], textarea[required]').each(function() {
                // Jika kosong
                if (!$(this).val()) {
                    isFormValid = false;
                    if (!firstInvalidField) {
                        firstInvalidField = $(this);
                    }
                    // Beri efek merah agar admin tahu bagian mana yang kurang
                    $(this).css({ 'border': '2px solid red', 'background-color': '#ffe6e6' });
                } else {
                    // Kembalikan ke warna normal jika sudah diisi
                    $(this).css({ 'border': '', 'background-color': '' });
                }
            });

            // Hapus efek merah saat user mulai mengetik
            $('input[required], select[required], textarea[required]').on('input change', function() {
                $(this).css({ 'border': '', 'background-color': '' });
            });

            // Jika ada yang belum diisi, HENTIKAN proses save agar halaman tidak reload!
            if (!isFormValid) {
                e.preventDefault(); // Mencegah form tersubmit ke server
                
                alert("TUNGGU! Ada kolom wajib (required) yang belum Anda isi. Silakan periksa kotak berwarna merah sebelum menyimpan, agar file foto yang Anda pilih tidak hilang.");
                
                // Arahkan layar otomatis ke kolom yang lupa diisi
                if (firstInvalidField) {
                    $('html, body').animate({
                        scrollTop: firstInvalidField.offset().top - 100
                    }, 500);
                    firstInvalidField.focus();
                }
            }
        });

    });
})(django.jQuery || jQuery);