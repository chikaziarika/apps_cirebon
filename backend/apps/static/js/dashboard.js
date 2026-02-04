// 1. Definisikan variabel GLOBAL di paling atas
window.currentSection = 0;
window.isAnimating = false;
let modalPieInstance = null;
let modalBarInstance = null;
let detailMap = null;      
let geojsonLayer = null;
let tableBangunanInstance = null;   
let currentData = {};


// Variabel penampung instance Chart agar bisa di-destroy
window.chartPrimer = null;
window.chartSekunder = null;
window.chartPintu = null;



$(document).ready(function() {
    gsap.registerPlugin(ScrollToPlugin);
    
    const container = $("#main-content");
    const sections = $(".gsap-section");


    function goToSection(index) {
        if (index < 0 || index >= sections.length || window.isAnimating) return;
        window.isAnimating = true;
        window.currentSection = index;
        const targetPos = index * window.innerHeight;

        gsap.to(container, { 
            scrollTo: { y: targetPos, autoKill: false },
            duration: 0.8,
            ease: "power2.inOut",
            onComplete: () => { 
                window.isAnimating = false; 
                $(".nav-dot").removeClass("active").eq(index).addClass("active");
            }
        });
    }

    $(document).on("click", ".nav-dot", function() {
        goToSection(parseInt($(this).attr("data-index")));
    });

    if(container.length > 0) {
        container[0].addEventListener("wheel", function(e) {
            if ($(e.target).closest('.table-responsive').length > 0) return;
            e.preventDefault();
            if (window.isAnimating) return;
            e.deltaY > 0 ? goToSection(window.currentSection + 1) : goToSection(window.currentSection - 1);
        }, { passive: false });
    }

function initDetailMap(dataKonten, bangunanData = []) {
    // 1. Bersihkan peta jika sudah ada
    if (detailMap !== null) {
        detailMap.remove();
        detailMap = null;
    }
    
    if (!document.getElementById('mapDetail')) return;

    // 2. Inisialisasi Map (Titik default sementara)
    detailMap = L.map('mapDetail').setView([0, 0], 2); 
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
    }).addTo(detailMap);

    // 3. Render GeoJSON & Auto Zoom
    if (dataKonten) {
        try {
            // Karena kita sudah pakai fetch().then(data => ...), dataKonten SUDAH berupa object
            let geoLayer = L.geoJson(dataKonten, {
                style: {
                    color: "#007bff",
                    weight: 4,
                    opacity: 0.8
                }
            }).addTo(detailMap);

            // AUTO ZOOM KE LOKASI
            const bounds = geoLayer.getBounds();
            if (bounds.isValid()) {
                detailMap.fitBounds(bounds, { padding: [30, 30] });
            }
        } catch (e) {
            console.error("Gagal merender layer GeoJSON:", e);
        }
    }

    // 4. Render Marker Bangunan (Jika ada)
    if (Array.isArray(bangunanData)) {
        bangunanData.forEach(item => {
            if (item.lat && item.lng) {
                L.marker([item.lat, item.lng])
                    .addTo(detailMap)
                    .bindPopup(`<b>${item.nama_bangunan}</b><br>${item.jenis}`);
            }
        });
    }

    // Penting agar peta tidak abu-abu di dalam modal/tab
    setTimeout(() => { 
        detailMap.invalidateSize(); 
    }, 400);
}


    function initBangunanTable() {
        if ($.fn.DataTable.isDataTable('#tableBangunan')) {
            $('#tableBangunan').DataTable().destroy();
        }

        $('#tableBangunan').DataTable({
            // Gunakan data dummy kamu yang sudah jalan
            data: [
                ["B.Cw.1 (Dummy)", "Sadap", "Baik", -6.826, 108.603, "No Photo"]
            ],
            columns: [
                { title: "No", render: (d,t,r,meta) => meta.row + 1 },
                { title: "Nama Bangunan" },
                { title: "Jenis" },
                { 
                    title: "Kondisi",
                    render: d => `<span class="badge bg-success">${d}</span>`
                },
                { 
                    title: "Koordinat",
                    render: (d, t, row) => {
                        // row[3] adalah lat, row[4] adalah lon
                        return `<a href="javascript:void(0)" onclick="focusKePeta(${row[3]}, ${row[4]}, '${row[1]}')" class="text-primary fw-bold">
                                    <i class="fa-solid fa-location-dot"></i> ${row[3]}, ${row[4]}
                                </a>`;
                    }
                },
                { title: "Foto" }
            ],
            pageLength: 5,
            responsive: true
        });
    }


    let charts = { primer: null, sekunder: null, pintu: null };

    function renderModalCharts(d) {
            const labels = ['Baik', 'Rusak Ringan', 'Rusak Berat', 'Belum Ada Pasangan'];
            const colors = ['#198754', '#ffc107', '#dc3545', '#6c757d'];

            const configs = [
                { id: 'chartPrimer', data: [d.p_baik, d.p_rr, d.p_rb, d.p_napas] },
                { id: 'chartSekunder', data: [d.s_baik, d.s_rr, d.s_rb, d.s_napas] },
                { id: 'chartPintu', data: [d.pt_baik, d.pt_rr, d.pt_rb, 0] }
            ];

            configs.forEach(config => {
                const canvas = document.getElementById(config.id);
                if (!canvas) return;

                const ctx = canvas.getContext('2d');

                // PERBAIKAN: Hancurkan instance lama dengan aman
                if (window[config.id] !== null && typeof window[config.id].destroy === 'function') {
                    window[config.id].destroy();
                }

                const totalValue = config.data.reduce((a, b) => a + b, 0);

                // Inisialisasi Chart Baru
                window[config.id] = new Chart(ctx, {
                    type: 'doughnut',
                    plugins: [ChartDataLabels], 
                    data: {
                        labels: labels,
                        datasets: [{
                            data: totalValue === 0 ? [1] : config.data,
                            backgroundColor: totalValue === 0 ? ['#e9ecef'] : colors,
                            borderWidth: 2
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            datalabels: {
                                display: totalValue > 0,
                                color: '#fff',
                                font: { weight: 'bold', size: 10 },
                                formatter: (value) => {
                                    return ((value * 100) / totalValue).toFixed(1) + "%";
                                }
                            },
                            legend: {
                                display: true,
                                position: 'bottom',
                                labels: { boxWidth: 10, font: { size: 9 } }
                            }
                        },
                        cutout: '65%'
                    }
                });
            });
        }


    $(document).on("click", ".view-detail", function() {

        const el = $(this);
        let diId = $(this).data('id'); 
         $('#id_di_aktif').val(diId)

        // 2. Ambil data dengan cara yang lebih aman
        const d = {
            nama: el.data('nama') || "-",
            sumber: el.data('sumber') || "-",
            bendung: el.data('bendung') || "-",
            permen: el.data('permen') || 0,
            onemap: el.data('onemap') || 0,
            // Konversi data chart ke angka
            p_baik: parseFloat(el.data('p_baik')) || 0,
            p_rr: parseFloat(el.data('p_rr')) || 0,
            p_rb: parseFloat(el.data('p_rb')) || 0,
            p_napas: parseFloat(el.data('p_napas')) || 0,
            s_baik: parseFloat(el.data('s_baik')) || 0,
            s_rr: parseFloat(el.data('s_rr')) || 0,
            s_rb: parseFloat(el.data('s_rb')) || 0,
            s_napas: parseFloat(el.data('s_napas')) || 0,
            pt_baik: parseFloat(el.data('pt_baik')) || 0,
            pt_rr: parseFloat(el.data('pt_rr')) || 0,
            pt_rb: parseFloat(el.data('pt_rb')) || 0
        };

        // 3. Update teks di UI Overlay
        $('#modalNama').text(d.nama);
        $('#modalSumber').text(': ' + d.sumber);
        $('#modalBendung').text(': ' + d.bendung);
        $('#modalPermen').text(d.permen);
        $('#modalOnemap').text(d.onemap);
        $('#titleIrigasi').text('Detail: ' + d.nama); // Update judul overlay

        // 4. Jalankan Animasi Muncul
        window.isAnimating = true;
        gsap.to("#detailOverlay", { 
            duration: 0.4, 
            display: "flex", 
            opacity: 1,
            ease: "power2.out",
            onComplete: function() {
                // Gambar Chart setelah animasi selesai agar ukurannya pas
                renderModalCharts(d);
                initBangunanTable();
            }
        });
        $("#modalBackdrop").fadeIn(300);

        // 5. Load GeoJSON (Jika ada)
        const geojsonRaw = el.data('geojson');
        if (geojsonRaw && geojsonRaw !== "") {
            fetch(geojsonRaw)
                .then(res => res.json())
                .then(data => {
                    // 1. Inisialisasi peta dan gambar GeoJSON saluran
                    initDetailMap(data); 
                    
                    // 2. LANGSUNG gambar marker bangunan setelah peta siap
                    renderMarkerBangunan(diId); 
                })
                .catch(err => console.error("Gagal load peta:", err));
        }
    });

    $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
        const targetId = $(e.target).attr('id');

        if (targetId === 'modal-map-tab') {
            if (detailMap) {
                setTimeout(() => {
                    detailMap.invalidateSize();
                }, 200);
            }
        }

        if (targetId === 'modal-data-tab') {
            if ($.fn.DataTable.isDataTable('#tableBangunan')) {
                $('#tableBangunan').DataTable().columns.adjust();
            }
        }
    });

    $("#closeOverlay").on("click", function() {
        gsap.to("#detailOverlay", { 
            duration: 0.3, 
            opacity: 0, 
            display: "none",
            onComplete: function() {
                window.isAnimating = false;
                $(".gsap-container").removeClass("hide-bullets");
            }
        });
    });

    function initModalCharts(lp, lf) {
        if (modalPieInstance) modalPieInstance.destroy();
        if (modalBarInstance) modalBarInstance.destroy();

        const pVal = parseFloat(lp) || 0;
        const fVal = parseFloat(lf) || 0;

        modalPieInstance = new Chart(document.getElementById('modalPieChart'), {
            type: 'doughnut',
            data: {
                labels: ['Permen', 'Fung.'],
                datasets: [{ data: [pVal, fVal], backgroundColor: ['#ffc107', '#28a745'] }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });

        modalBarInstance = new Chart(document.getElementById('modalBarChart'), {
            type: 'bar',
            data: {
                labels: ['Permen', 'Fung.'],
                datasets: [{ label: 'Ha', data: [pVal, fVal], backgroundColor: ['#ffc107', '#28a745'] }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
    }

    $('#sidebarCollapse').on('click', function() {
        $('#sidebar').toggleClass('active');
    });


    function createConditionChart(canvasId, dataB, dataRR, dataRB) {
        const ctx = document.getElementById(canvasId).getContext('2d');
        
        if (window[canvasId] instanceof Chart) {
            window[canvasId].destroy();
        }

        window[canvasId] = new Chart(ctx, {
            type: 'doughnut', // Doughnut lebih modern daripada Pie biasa
            data: {
                labels: ['Baik', 'RR', 'RB'],
                datasets: [{
                    data: [dataB, dataRR, dataRB],
                    backgroundColor: ['#198754', '#ffc107', '#dc3545'], // Hijau, Kuning, Merah
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom', labels: { boxWidth: 12, font: { size: 10 } } }
                }
            }
        });
    }

    $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
        if (e.target.id === 'modal-map-tab') {
            if (detailMap) {
                detailMap.invalidateSize();
                // Opsional: Zoom ulang saat tab dibuka agar posisi pas
                const layers = [];
                detailMap.eachLayer(l => { if(l.getBounds) layers.push(l); });
                if(layers.length > 0) detailMap.fitBounds(layers[0].getBounds());
            }
        }
    });

    function loadDummyData() {
        // Dummy Bangunan (Sekitar jalur Ciwado)
        const bangunan = [
            { nama: "B.Cw.1 (Sadap)", jenis: "Bangunan Sadap", kondisi: "Baik", lat: -6.8263, lon: 108.6038 },
            { nama: "B.Cw.2 (Bagi)", jenis: "Bangunan Bagi", kondisi: "Rusak Ringan", lat: -6.8123, lon: 108.6144 },
            { nama: "B.Cw.3 (Gorong)", jenis: "Gorong-gorong", kondisi: "Baik", lat: -6.7935, lon: 108.6336 }
        ];

        // Dummy Saluran
        const saluran = [
            { nama: "Primer Ciwado", tipe: "Tanah", panjang: 1250, kondisi: "75% Baik" },
            { nama: "Sekunder Ciwado Kanan", tipe: "Pasangan Batu", panjang: 850, kondisi: "60% Baik" },
            { nama: "Sekunder Ciwado Kiri", tipe: "Beton", panjang: 5573, kondisi: "90% Baik" }
        ];

        // Isi Tabel Bangunan
        let htmlBangunan = "";
        bangunan.forEach(b => {
            htmlBangunan += `<tr>
                <td>${b.nama}</td>
                <td>${b.jenis}</td>
                <td><span class="badge ${b.kondisi === 'Baik' ? 'bg-success' : 'bg-warning'}">${b.kondisi}</span></td>
                <td>${b.lat}, ${b.lon}</td>
            </tr>`;
        });
        document.getElementById('bodyBangunan').innerHTML = htmlBangunan;

        // Isi Tabel Saluran
        let htmlSaluran = "";
        saluran.forEach(s => {
            htmlSaluran += `<tr>
                <td>${s.nama}</td>
                <td>${s.tipe}</td>
                <td>${s.panjang}</td>
                <td>${s.kondisi}</td>
            </tr>`;
        });
        document.getElementById('bodySaluran').innerHTML = htmlSaluran;
    }

    document.getElementById('peta-tab').addEventListener('shown.bs.modal', function () {
        setTimeout(() => {
            mapDetail.invalidateSize();
        }, 200);
    });
    

});

// PINDAHKAN KE LUAR $(document).ready
function focusKePeta(lat, lon, nama = "Lokasi Bangunan") {
    // 1. Pindah ke Tab Peta secara otomatis
    const tabEl = document.querySelector('#modal-map-tab');
    if (tabEl) { 
        new bootstrap.Tab(tabEl).show(); 
    }

    // 2. Tunggu sebentar (animasi tab), lalu gerakkan peta
    setTimeout(() => {
        if (detailMap) {
            detailMap.invalidateSize();
            detailMap.setView([lat, lon], 18); // Zoom dekat
            
            // Tambahkan marker fokus
            L.marker([lat, lon]).addTo(detailMap)
                .bindPopup(`<b>${nama}</b>`)
                .openPopup();
        }
    }, 400);
}

// Tambahkan ini di paling bawah dashboard.js untuk menangkap data marker saat modal dibuka
function loadMarkerBangunan(diId) {
    fetch(`/api/bangunan/${diId}/`)
        .then(res => res.json())
        .then(response => {
            const data = response.data;
            if (Array.isArray(data) && detailMap) {
                data.forEach(item => {
                    if (item.latitude && item.longitude) {
                        L.marker([item.latitude, item.longitude])
                            .addTo(detailMap)
                            .bindPopup(`<b>${item.nama_bangunan}</b><br>${item.kondisi_aset}`);
                    }
                });
            }
        })
        .catch(err => console.error("Gagal load marker:", err));
}

function renderMarkerBangunan(diId) {
    // Pastikan peta sudah siap
    if (!detailMap) return;

    // Ambil data dari API Bangunan
    fetch(`/api/bangunan/${diId}/`)
        .then(res => res.json())
        .then(response => {
            const data = response.data;
            if (Array.isArray(data)) {
                data.forEach(item => {
                    if (item.latitude && item.longitude) {
                        // Tambahkan marker ke peta
                        L.marker([item.latitude, item.longitude])
                            .addTo(detailMap)
                            .bindPopup(`<b>${item.nama_bangunan}</b><br>Kondisi: ${item.kondisi_aset}`);
                    }
                });
            }
        })
        .catch(err => console.error("Gagal memuat marker bangunan:", err));
}