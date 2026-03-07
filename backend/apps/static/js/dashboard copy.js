
window.currentSection = 0;
window.isAnimating = false;

// Chart Instances
let chartObjUtama = null;
let chartObjBanding = null;
let chartObjP = null;
let chartObjS = null;
let chartInteraktif = null;
let chartDetailLuasBarObj = null;
let chartDetailLuasPieObj = null;
let chartGaugePintuObj = null;
let chartSebaranRankingObj = null;

// Modal & Map Instances
let modalPieInstance = null;
let modalBarInstance = null;
let detailMap = null;    
let mapKeseluruhan = null;  
let diLayers = {};
let diDataMap = {};
let currentView = 'permen';

// DataTable Instance (GLOBAL AGAR BISA DIAKSES EVENT LISTENER)
var tableBangunanInstance = null;



function hideAllDetails() {
    $("#view-ringkasan, #view-drilldown, #view-detail-luas, #view-detail-distribusi, #view-detail-sebaran").hide();
}

/**
 * Navigasi antar section utama (Scroll effect)
 */
function goToSection(index) {
    const sections = $(".gsap-section");
    if (index < 0 || index >= sections.length || window.isAnimating) return;
    window.isAnimating = true;
    window.currentSection = index;
    const targetPos = index * window.innerHeight;

    gsap.to("#main-content", { 
        scrollTo: { y: targetPos, autoKill: false },
        duration: 0.8,
        ease: "power2.inOut",
        onComplete: () => { 
            window.isAnimating = false; 
            $(".nav-dot").removeClass("active").eq(index).addClass("active");
        }
    });
}

let isFlowView = false;

function toggleDistribusiView() {
    const btn = $("#btn-toggle-distribusi");
    const title = $("#distribusi-title");
    const summary = $("#distribusi-summary-view");
    const flowchart = $("#distribusi-flowchart-view");

    if (!isFlowView) {
        // PINDAH KE FLOWCHART
        gsap.to(summary, { duration: 0.3, opacity: 0, y: -20, display: "none" });
        gsap.fromTo(flowchart, 
            { display: "none", opacity: 0, y: 20 },
            { duration: 0.4, display: "block", opacity: 1, y: 0, ease: "power2.out", onComplete: () => {
                // Render Mermaid
                const el = document.getElementById('skema-mermaid-dashboard');
                el.innerHTML = window.currentFlowchartDef || "graph TD\n  A[Data Skema Belum Diatur]";
                el.removeAttribute('data-processed');
                mermaid.init(undefined, el);
            }}
        );
        
        btn.html('<i class="fa-solid fa-chart-pie me-2"></i>Lihat Ringkasan');
        title.text("Skema Jaringan & Aliran Irigasi");
        isFlowView = true;
    } else {
        // KEMBALI KE RINGKASAN
        gsap.to(flowchart, { duration: 0.3, opacity: 0, y: 20, display: "none" });
        gsap.fromTo(summary, 
            { display: "none", opacity: 0, y: -20 },
            { duration: 0.4, display: "flex", opacity: 1, y: 0, ease: "power2.out", onComplete: () => {
                renderChartGaugePintu(); // Render ulang gauge agar sizenya pas
            }}
        );
        
        btn.html('<i class="fa-solid fa-diagram-project me-2"></i>Lihat Skema Jaringan');
        title.text("Kondisi Infrastruktur Pengatur Air (Pintu)");
        isFlowView = false;
    }
}


function backToRingkasan() {
    isFlowView = false;
    $("#main-content").css("overflow", "auto");
    gsap.to(".container-fluid", { duration: 0.2, opacity: 0, onComplete: () => {
        hideAllDetails();
        $("#view-ringkasan").show();
        gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });
        gsap.to("#main-content", { scrollTo: 0, duration: 0 }); 
        initKomposisiCharts();
    }});
}

// =========================================================
// 3. LOGIKA CARD CLICK / DRILLDOWN (SUPORT AUTO-SWITCH)
// =========================================================

function showDrillDownJaringan() { 
    $("#main-content").css("overflow", "hidden"); // Matikan scroll agar stabil
    gsap.to(".container-fluid", { duration: 0.2, opacity: 0, onComplete: () => {
        hideAllDetails();
        $("#view-drilldown").css({"display": "block", "opacity": 1}).show(); 
        gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });
        renderSubDetailCharts();
    }});
}

// Alias jika dipanggil via showDrillDown() di chart utama
function showDrillDown() { showDrillDownJaringan(); }

function showDrillDownLuas() {
    $("#main-content").css("overflow", "hidden");
    gsap.to(".container-fluid", { duration: 0.2, opacity: 0, onComplete: () => {
        hideAllDetails();
        $("#view-detail-luas").css({"display": "block", "opacity": 1}).show();
        gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });
        renderChartsDetailLuas();
    }});
}

function showDrillDownDistribusi() {
    $("#main-content").css("overflow", "hidden");
    
    gsap.to(".container-fluid", { 
        duration: 0.2, 
        opacity: 0, 
        onComplete: () => {
            hideAllDetails();
            
            // 1. Munculkan Div
            const $distDiv = $("#view-detail-distribusi");
            $distDiv.show().css({"display": "block", "opacity": 1});
            
            // 2. Animasi Masuk
            gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });

            // 3. Render Grafik Gauge
            // Pastikan Anda mempassing data rekap_pintu dari Django ke JS
            renderChartGaugePintu();

            // 4. Render Flowchart Mermaid
            renderDashboardFlowchart();
        }
    });
}

function renderDashboardFlowchart() {
    const el = document.getElementById('skema-mermaid-dashboard');
    // Ambil skema gabungan dari views.py
    const chartDef = window.global_flow_str || `graph TD
    BD_Ciwado["<i class='fa fa-water'></i> BD. Ciwado"]
    BWd_1["<i class='fa fa-door-open'></i> BWd. 1"]
    BWd_2["<i class='fa fa-door-open'></i> BWd. 2"]
    
    BD_Ciwado -->|Sal. Induk| BWd_1
    BWd_1 -->|Sal. Induk| BWd_2
    
    class BD_Ciwado type-B01
    class BWd_1,BWd_2 type-S01`;

    if (el) {
        el.innerHTML = chartDef;
        el.removeAttribute('data-processed');
        mermaid.init(undefined, el);
    }
}


function showDrillDownSebaran() {
    $("#main-content").css("overflow", "hidden");
    gsap.to(".container-fluid", { duration: 0.2, opacity: 0, onComplete: () => {
        hideAllDetails();
        $("#view-detail-sebaran").css({"display": "block", "opacity": 1}).show();
        gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });
        renderRankingSebaran();
    }});
}

// =========================================================
// 4. CORE INITIALIZATION (LABELS, TABS, ETC)
// =========================================================

function updateStatsLabels() {
    const pData = window.dataPrimer || [0,0,0,0];
    const sData = window.dataSekunder || [0,0,0,0];
    const totalP = pData.reduce((a, b) => a + b, 0);
    const totalS = sData.reduce((a, b) => a + b, 0);
    $('#label-total-semua').text((totalP + totalS).toLocaleString('id-ID'));
    $('#label-total-primer').text(totalP.toLocaleString('id-ID'));
    $('#label-total-sekunder').text(totalS.toLocaleString('id-ID'));
}

$(document).ready(function() {
    gsap.registerPlugin(ScrollToPlugin);

    // Init Chart Utama
    initKomposisiCharts();
    initBandingLuasChart();
    initChartLuasSimple();
    updateStatsLabels();

    // Init Peta Utama (Delay sedikit agar container siap)
    setTimeout(() => { initMapKeseluruhan(); }, 500);

    // Sidebar Toggle
    $('#sidebarCollapse').on('click', function() { $('#sidebar').toggleClass('active'); });

    // Scroll Mouse Wheel (Navigasi Section)
    const container = $("#main-content");
    if (container.length > 0 && container[0]) {
        container[0].addEventListener("wheel", function(e) {
            if ($(e.target).closest('.table-responsive').length > 0) return;
            if ($("#view-ringkasan").is(":hidden")) return; // Jangan scroll section jika sedang di detail
            e.preventDefault();
            if (window.isAnimating) return;
            e.deltaY > 0 ? goToSection(window.currentSection + 1) : goToSection(window.currentSection - 1);
        }, { passive: false });
    }

    // --- SATU EVENT LISTENER UNTUK SEMUA TAB (PENTING: BIAR GAK BENTROK) ---
    $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
        const targetId = $(e.target).attr('id');
        const diId = $('#id_di_aktif').val(); // Ambil ID DI yang sedang aktif

        // 1. Tab Chart Utama
        if (targetId === 'chart-tab') {
            initKomposisiCharts();
            initBandingLuasChart();
        }
        // 2. Tab Peta Utama
        if (targetId === 'stats-tab') {
            initMapKeseluruhan();
        }
        // 3. Tab Saluran (Di dalam Modal)
        if (targetId === 'modal-saluran-tab') {
            if(diId) loadSaluranTable(diId);
        }
        // 4. Tab Bangunan (Di dalam Modal)
        if (targetId === 'modal-bangunan-tab') {
            // Cek apakah ada filter titipan
            if (window.currentFilterSaluran) {
                loadBangunanTable(diId, window.currentFilterId, window.currentFilterSaluran);
            } else {
                // Load default jika tabel belum ada atau kosong
                // ATAU jika DataTable sudah ada, paksa adjust column biar gak berantakan
                if (!$.fn.DataTable.isDataTable('#tabelBangunan')) {
                    loadBangunanTable(diId);
                } else {
                    $('#tabelBangunan').DataTable().columns.adjust();
                }
            }
        }
        // 5. Tab Peta Detail (Di dalam Modal)
        if (targetId === 'modal-map-tab') {
            console.log("📍 Tab Peta Detail Aktif. Merefresh Peta...");
            if (detailMap) {
                // Berikan sedikit delay agar transisi fade Bootstrap selesai
                setTimeout(() => {
                    detailMap.invalidateSize();
                    console.log("✅ invalidateSize Berhasil");
                }, 300);
            } else {
                // Jika karena suatu hal peta belum di-init, init sekarang
                initDetailMap(diId);
            }
        }
    });
});

// =========================================================
// 5. SEMUA FUNGSI CHART RENDERING (UTUH)
// =========================================================

function initKomposisiCharts() {
    const canvas = document.getElementById('chartUtamaKeseluruhan');
    if (!canvas) return;
    const dataValues = window.dataKondisiKeseluruhan || [0, 0, 0];
    const totalData = dataValues.reduce((a, b) => a + b, 0);

    if (window.chartObjUtama) window.chartObjUtama.destroy();
    window.chartObjUtama = new Chart(canvas.getContext('2d'), {
        type: 'doughnut',
        plugins: [ChartDataLabels],
        data: {
            labels: ['Baik', 'Rusak Ringan', 'Rusak Berat'],
            datasets: [{
                data: dataValues,
                backgroundColor: ['#40916c', '#ffc107', '#f39c12'], 
                borderWidth: 5
            }]
        },
        options: {
            maintainAspectRatio: false,
            cutout: '70%',
            plugins: {
                datalabels: {
                    color: '#fff',
                    font: { weight: 'bold', size: 12 },
                    formatter: (value) => value === 0 ? null : ((value * 100) / totalData).toFixed(1) + "%"
                },
                tooltip: {
                    callbacks: { label: (ctx) => ` Total: ${ctx.raw.toLocaleString()} Meter` }
                },
                legend: { position: 'bottom' }
            },
            onClick: () => showDrillDownJaringan()
        }
    });
}

function initBandingLuasChart() {
    const canvas = document.getElementById('chartBandingLuas');
    if (!canvas) return;
    if (chartObjBanding) chartObjBanding.destroy();
    chartObjBanding = new Chart(canvas.getContext('2d'), {
        type: 'bar',
        data: {
            labels: ['Total Luas Kabupaten'],
            datasets: [
                { label: 'Target Permen No. 14', data: [window.dataBandingLuas ? window.dataBandingLuas[0] : 0], backgroundColor: '#0d3b66', borderRadius: 8 },
                { label: 'Realisasi Fungsional', data: [window.dataBandingLuas ? window.dataBandingLuas[1] : 0], backgroundColor: '#ee964b', borderRadius: 8 }
            ]
        },
        options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true } } }
    });
}

function initChartLuasSimple() {
    const data = {
        permen: window.dataLuas?.baku_permen || 0,
        onemap: window.dataLuas?.baku_onemap || 0,
        potensial: window.dataLuas?.potensial || 0,
        fungsional: window.dataLuas?.fungsional || 0
    };
    $('#val-pot-anim').text(data.potensial.toLocaleString('id-ID'));
    $('#val-fung-anim').text(data.fungsional.toLocaleString('id-ID'));
    $('#val-baku-anim').text(data.permen.toLocaleString('id-ID'));

    const ctx = document.getElementById('chartLuasInteraktif')?.getContext('2d');
    if(!ctx) return;
    if(chartInteraktif) chartInteraktif.destroy();
    chartInteraktif = new Chart(ctx, {
        type: 'doughnut',
        plugins: [ChartDataLabels],
        data: {
            labels: ['Fungsional', 'Potensial Non-Fung', 'Sisa Baku'],
            datasets: [{
                data: [data.fungsional, (data.potensial - data.fungsional), (data.permen - data.potensial)],
                backgroundColor: ['#198754', '#ffc107', '#e9ecef'],
                borderWidth: 0
            }]
        },
        options: {
            maintainAspectRatio: false, cutout: '75%',
            plugins: {
                legend: { display: false },
                datalabels: {
                    formatter: (val, ctx) => ctx.dataIndex === 0 ? ((val / ctx.dataset.data.reduce((a, b) => a + b, 0)) * 100).toFixed(1) + '%' : '',
                    color: '#fff', font: { weight: 'bold', size: 12 }
                }
            }
        }
    });
    // Toggle logic
    $('#btn-switch-data').off('click').on('click', function() {
        if (currentView === 'permen') {
            currentView = 'onemap';
            $(this).html('<i class="fas fa-exchange-alt me-2"></i>Ganti ke Data Permen');
            $('#label-baku').text('Luas Baku (OneMap)');
            $('#val-baku-anim').text(data.onemap.toLocaleString('id-ID'));
            chartInteraktif.data.datasets[0].data = [data.fungsional, (data.potensial - data.fungsional), (data.onemap - data.potensial)];
        } else {
            currentView = 'permen';
            $(this).html('<i class="fas fa-exchange-alt me-2"></i>Ganti ke Data OneMap');
            $('#label-baku').text('Luas Baku (Permen)');
            $('#val-baku-anim').text(data.permen.toLocaleString('id-ID'));
            chartInteraktif.data.datasets[0].data = [data.fungsional, (data.potensial - data.fungsional), (data.permen - data.potensial)];
        }
        chartInteraktif.update();
    });
}

function renderSubDetailCharts() {
    const labels = ['Baik', 'Rusak Ringan', 'Rusak Berat', 'BAP'];
    const colors = ['#40916c', '#ffc107', '#f39c12', '#6c757d'];
    const createChart = (canvasId, data, title) => {
        const ctx = document.getElementById(canvasId);
        if (!ctx || !data) return;
        const total = data.reduce((a, b) => a + b, 0);
        return new Chart(ctx.getContext('2d'), {
            type: 'pie', plugins: [ChartDataLabels],
            data: { labels: labels, datasets: [{ data: data, backgroundColor: colors }] },
            options: { maintainAspectRatio: false, plugins: { datalabels: { color: '#fff', formatter: (val) => val === 0 ? null : ((val * 100) / total).toFixed(1) + "%" }, title: { display: true, text: title } } }
        });
    };
    if(chartObjP) chartObjP.destroy();
    chartObjP = createChart('chartDetailPrimer', window.dataPrimer, 'Kondisi Jaringan Primer');
    if(chartObjS) chartObjS.destroy();
    chartObjS = createChart('chartDetailSekunder', window.dataSekunder, 'Kondisi Jaringan Sekunder');
}

function renderChartsDetailLuas() {
    const labels = []; const dataBaku = []; const dataFungsional = [];
    window.dataIrigasiFull.slice(0, 10).forEach(di => { labels.push(di.nama_di); dataBaku.push(di.luas_baku_permen); dataFungsional.push(di.luas_fungsional); });
    if (chartDetailLuasBarObj) chartDetailLuasBarObj.destroy();
    chartDetailLuasBarObj = new Chart(document.getElementById('chartDetailLuasBar').getContext('2d'), {
        type: 'bar', data: { labels: labels, datasets: [{ label: 'Luas Baku', data: dataBaku, backgroundColor: '#6c757d' }, { label: 'Luas Fungsional', data: dataFungsional, backgroundColor: '#198754' }] },
        options: { responsive: true, maintainAspectRatio: false }
    });
    if (chartDetailLuasPieObj) chartDetailLuasPieObj.destroy();
    chartDetailLuasPieObj = new Chart(document.getElementById('chartDetailLuasPie').getContext('2d'), {
        type: 'pie', data: { labels: ['Terairi', 'Belum Terairi'], datasets: [{ data: [window.dataLuas.fungsional, window.dataLuas.baku_permen - window.dataLuas.fungsional], backgroundColor: ['#198754', '#e9ecef'] }] },
        options: { maintainAspectRatio: false }
    });
}

function renderChartGaugePintu() {
    const d = window.dataPintuGlobal;
    if (!d || d.total === 0) return; // Proteksi jika data kosong

    if (chartGaugePintuObj) chartGaugePintuObj.destroy();

    const ctx = document.getElementById('chartGaugePintu').getContext('2d');
    
    chartGaugePintuObj = new Chart(ctx, {
        type: 'doughnut',
        plugins: [ChartDataLabels],
        data: {
            labels: ['Baik', 'RR', 'RB'],
            datasets: [{
                data: [d.baik, d.rr, d.rb],
                backgroundColor: ['#198754', '#ffc107', '#dc3545'],
                borderWidth: 2,
                borderColor: '#ffffff',
                circumference: 180, // Membuat setengah lingkaran
                rotation: 270,      // Memutar agar lengkungan di atas
                cutout: '75%'       // Membuat ketebalan donat yang elegan
            }]
        },
        options: {
            maintainAspectRatio: false,
            layout: {
                padding: {
                    bottom: 20 // Memberi ruang untuk angka di tengah bawah
                }
            },
            plugins: {
                legend: {
                    display: true,
                    position: 'bottom',
                    labels: {
                        usePointStyle: true,
                        padding: 15,
                        font: { size: 10 }
                    }
                },
                datalabels: {
                    display: function(context) {
                        // Hanya tampilkan label jika nilainya lebih dari 0
                        return context.dataset.data[context.dataIndex] > 0;
                    },
                    formatter: (val) => {
                        return d.total > 0 ? ((val / d.total) * 100).toFixed(0) + '%' : '';
                    },
                    color: '#fff',
                    font: { weight: 'bold', size: 11 },
                    anchor: 'center',
                    align: 'center'
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return ` ${context.label}: ${context.raw} Unit`;
                        }
                    }
                }
            }
        }
    });

    // Update Angka Persentase Kesehatan di Elemen HTML (Jika ada)
    const healthScore = d.total > 0 ? ((d.baik / d.total) * 100).toFixed(0) : 0;
    $('#scoreText').text(healthScore + '%');
}

function renderRankingSebaran() {
    if (!window.dataIrigasiFull) return;
    const sortedData = [...window.dataIrigasiFull].sort((a, b) => parseFloat(b.baik) - parseFloat(a.baik));
    const labels = sortedData.map(d => d.nama_di);
    const baikData = sortedData.map(d => parseFloat(d.baik) || 0);
    const rusakData = sortedData.map(d => (parseFloat(d.rr) || 0) + (parseFloat(d.rb) || 0));
    if (chartSebaranRankingObj) chartSebaranRankingObj.destroy();
    chartSebaranRankingObj = new Chart(document.getElementById('chartSebaranRanking').getContext('2d'), {
        type: 'bar', data: { labels: labels, datasets: [{ label: 'Baik', data: baikData, backgroundColor: '#198754' }, { label: 'Rusak', data: rusakData, backgroundColor: '#dc3545' }] },
        options: { indexAxis: 'y', maintainAspectRatio: false, scales: { x: { stacked: true }, y: { stacked: true } } }
    });
    let tableHtml = '';
    sortedData.forEach(d => {
        const total = (parseFloat(d.baik) || 0) + (parseFloat(d.rr) || 0) + (parseFloat(d.rb) || 0);
        const persen = total > 0 ? ((d.baik / total) * 100).toFixed(1) : 0;
        tableHtml += `<tr><td class="fw-bold">${d.nama_di}</td><td><div class="progress"><div class="progress-bar ${persen > 70 ? 'bg-success' : 'bg-warning'}" style="width: ${persen}%"></div></div> <span class="fw-bold">${persen}%</span></td></tr>`;
    });
    $('#tableRankingSebaran tbody').html(tableHtml);
}

    function initDetailMap(inputData) {
        // 1. Reset Peta Lama
        if (detailMap !== null) { 
            detailMap.remove(); 
            detailMap = null; 
        }
        
        const mapContainer = document.getElementById('mapDetail');
        if (!mapContainer) return;

        // --- 2. TAMPILKAN PETA DASAR SEKARANG JUGA (ANTI-BLANK) ---
        // Dipasang di awal agar basemap OSM langsung muncul tanpa syarat data
        detailMap = L.map('mapDetail').setView([-6.826, 108.604], 14); 
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(detailMap);

        // Paksa refresh ukuran agar tidak putih saat modal/overlay terbuka
        [100, 300, 700].forEach(delay => {
            setTimeout(() => { if(detailMap) detailMap.invalidateSize(); }, delay);
        });

        // 3. Ambil ID Daerah Irigasi
        let diId = (typeof inputData === 'object' && inputData !== null) ? $('#id_di_aktif').val() : inputData;

        // 4. Proses Load Data (Hanya dijalankan jika ID tersedia)
        if (diId) {
            console.log(`📡 Memuat data detail ID: ${diId}`);

            // --- PROSES 1: LOAD GARIS SALURAN ---
            fetch(`/api/saluran/${diId}/`)
                .then(res => res.json())
                .then(response => {
                    const daftarSaluran = response.data || [];
                    if (daftarSaluran.length > 0) {
                        let allLayers = [];
                        daftarSaluran.forEach(saluran => {
                            const geoData = saluran.geometry_data || saluran.geom;

                            // VALIDASI: Hanya gambar jika GeoJSON benar-benar ada dan valid
                            if (geoData && geoData !== "" && geoData !== "{}" && geoData !== null) {
                                const layer = L.geoJson(geoData, {
                                    style: { 
                                        color: "#007bff", 
                                        weight: 6, 
                                        opacity: 0.9,
                                        lineJoin: 'round',
                                        lineCap: 'round'
                                    }
                                }).addTo(detailMap);
                                
                                layer.bindTooltip(`<b>${saluran.nama_saluran}</b>`, { sticky: true });
                                layer.bindPopup(`<b>${saluran.nama_saluran}</b><br>Panjang: ${saluran.panjang_saluran || '-'} m`);

                                layer.on('mouseover', function () { this.setStyle({ weight: 10, color: "#ffc107", opacity: 1 }); });
                                layer.on('mouseout', function () { this.setStyle({ weight: 6, color: "#007bff", opacity: 0.9 }); });

                                allLayers.push(layer);
                            }
                        });

                        if (allLayers.length > 0) {
                            const featureGroup = L.featureGroup(allLayers);
                            detailMap.fitBounds(featureGroup.getBounds(), { padding: [40, 40] });
                        }
                    }
                }).catch(err => console.error("❌ Gagal load saluran:", err));

            // --- PROSES 2: LOAD MARKER BANGUNAN ---
            fetch(`/api/bangunan/${diId}/`)
                .then(res => res.json())
                .then(response => {
                    const daftarBangunan = response.data || [];
                    daftarBangunan.forEach(b => {
                        let rawLat = parseFloat(b.latitude);
                        let rawLng = parseFloat(b.longitude);
                        let fixLat = (Math.abs(rawLat) > 90) ? rawLng : rawLat;
                        let fixLng = (Math.abs(rawLat) > 90) ? rawLat : rawLng;

                        if (fixLat !== 0 && !isNaN(fixLat)) {
                            var iconAset = L.icon({
                                iconUrl: `/static/icons/${b.kode_aset || 'default'}.png`,
                                iconSize: [30, 30],      // Ukuran icon di peta
                                iconAnchor: [15, 15],    // Titik tengah icon
                                popupAnchor: [0, -15]    // Posisi popup
                            });

                            // 2. PASANG MARKER DENGAN PARAMETER { icon: iconAset }
                            const marker = L.marker([fixLat, fixLng], { icon: iconAset }).addTo(detailMap);
                            marker.bindPopup(`
                                <div style="width: 180px; font-family: sans-serif;">
                                    <div style="background: #0d3b66; color: white; padding: 8px; border-radius: 4px; text-align: center; font-weight: bold; font-size: 12px; margin-bottom: 8px;">
                                        ${b.nomenklatur_ruas || b.nama_bangunan || "Bangunan"}
                                    </div>
                                    <table style="width: 100%; font-size: 11px;">
                                        <tr><td>Saluran</td><td style="font-weight:bold; text-align:right;">${b.nama_saluran || "-"}</td></tr>
                                        <tr><td>Luas</td><td style="font-weight:bold; text-align:right;">${b.luas_areal || 0} Ha</td></tr>
                                    </table>
                                    <hr style="margin: 8px 0;">
                                    <a href="https://www.google.com/maps?q=${fixLat},${fixLng}" target="_blank" class="btn btn-primary btn-sm w-100 text-white" style="font-size: 10px;">
                                        PETUNJUK ARAH
                                    </a>
                                </div>
                            `);
                        }
                    });
                }).catch(err => console.error("❌ Gagal load bangunan:", err));
        }
    }

    function renderModalCharts(d) {
    const labels = ['Baik', 'Rusak Ringan', 'Rusak Berat', 'BAP'];
    const colors = ['#198754', '#ffc107', '#dc3545', '#6c757d'];

    const configs = [
        { 
            id: 'chartPrimer', 
            data: [d.primer_baik, d.primer_rr, d.primer_rb, d.primer_bap] 
        },
        { 
            id: 'chartSekunder', 
            data: [d.sekunder_baik, d.sekunder_rr, d.sekunder_rb, d.sekunder_bap] 
        },
        { 
            id: 'chartPintu', 
            data: [d.pintu_baik, d.pintu_rr, d.pintu_rb, 0] 
        }
    ];

    configs.forEach(config => {
        const canvas = document.getElementById(config.id);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        if (window[config.id] instanceof Chart) {
            window[config.id].destroy();
        }

        const totalValue = config.data.reduce((a, b) => a + b, 0);

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
                        formatter: (val) => ((val * 100) / totalValue).toFixed(1) + "%"
                    },
                    legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 9 } } }
                },
                cutout: '65%'
            }
        });
    });
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
// =========================================================
// 6. MODAL OVERLAY DETAIL (MARKER KLIK)
// =========================================================
$(document).on("click", ".view-detail", function() {
    const el = $(this);
    let diId = el.data('id'); 
    $('#id_di_aktif').val(diId);

    // --- SOLUSI AMPUH: Ambil data utuh dari JSON API yang dititipkan ---
    // Pastikan saat render tabel utama, Bapak sudah menambahkan data-json
    let d = el.data('json'); 

    

    // Jika d masih undefined (karena belum pakai data-json), 
    // kita gunakan mapping manual tapi dengan NAMA FIELD ASLI API
    if (!d) {
        console.warn("Data JSON tidak ditemukan, menggunakan mapping manual...");
        d = {
            nama_di: el.data('nama') || "-",
            sumber_air: el.data('sumber') || "-",
            bendung: el.data('bendung') || "-",
            luas_baku_permen: el.data('permen') || 0,
            luas_baku_onemap: el.data('onemap') || 0,
            
            // DATA PRIMER (Gunakan nama field asli API)
            primer_baik: parseFloat(el.data('p_baik')) || 0,
            primer_rr: parseFloat(el.data('p_rr')) || 0,
            primer_rb: parseFloat(el.data('p_rb')) || 0,
            primer_bap: parseFloat(el.data('p_napas')) || 0,

            // DATA SEKUNDER (Ini yang kemarin hilang)
            sekunder_baik: parseFloat(el.data('s_baik')) || 0,
            sekunder_rr: parseFloat(el.data('s_rr')) || 0,
            sekunder_rb: parseFloat(el.data('s_rb')) || 0,
            sekunder_bap: parseFloat(el.data('s_napas')) || 0,

            // DATA PINTU
            pintu_baik: parseFloat(el.data('pt_baik')) || 0,
            pintu_rr: parseFloat(el.data('pt_rr')) || 0,
            pintu_rb: parseFloat(el.data('pt_rb')) || 0,

            panjang_primer: parseFloat(el.data('p_primer')) || 0,
            panjang_sekunder: parseFloat(el.data('p_sekunder')) || 0,
            jml_bangunan: parseInt(el.data('jml_bgn')) || 0,
            jml_pintu: parseInt(el.data('jml_pintu')) || 0,
            
            geojson: el.data('geojson')
        };
    }

    console.log("DEBUG: Data yang akan dikirim ke Chart:", d);

    // Update UI Modal

    const pBaik = parseFloat(d.pintu_baik) || 0;
    const pRR = parseFloat(d.pintu_rr) || 0;
    const pRB = parseFloat(d.pintu_rb) || 0;
    const totalSeluruhPintu = pBaik + pRR + pRB;

    $('#countPrimer').text(d.panjang_primer.toLocaleString('id-ID') + ' m');
    $('#countSekunder').text(d.panjang_sekunder.toLocaleString('id-ID') + ' m');
    $('#countTotalSal').text((d.panjang_primer + d.panjang_sekunder).toLocaleString('id-ID') + ' m');
    $('#countBangunan').text(d.jml_bangunan);
    $('#countPintu').text(totalSeluruhPintu );
    $('#modalNama').text(d.nama_di || d.nama);
    $('#modalSumber').text(': ' + (d.sumber_air || d.sumber));
    $('#modalBendung').text(': ' + (d.bendung || d.bendung));
    $('#modalPermen').text(d.luas_baku_permen || d.permen);
    $('#modalOnemap').text(d.luas_baku_onemap || d.onemap);
    $('#titleIrigasi').text('Detail: ' + (d.nama_di || d.nama));
    
    fetch(`/api/bangunan/${diId}/`)
        .then(res => res.json())
        .then(response => {
            const dataBangunan = response.data || [];
            // Isi angka Jumlah Bangunan berdasarkan jumlah baris data yang ada
            $('#countBangunan').text(dataBangunan.length); 
            
            // Simpan data ke variabel global agar bisa dipakai fungsi lain (opsional)
            window.currentBangunanData = dataBangunan; 
        })
        .catch(err => {
            console.error("Gagal hitung bangunan:", err);
            $('#countBangunan').text("0");
        });

    // Animasi Overlay
    window.isAnimating = true;
    gsap.to("#detailOverlay", { 
        duration: 0.4, display: "flex", opacity: 1, ease: "power2.out",
        onComplete: function() {
            console.log("🚩 MODAL TERBUKA - MEMANGGIL PETA UNTUK ID:", diId);
            
            renderModalCharts(d); 
            loadSaluranTable(diId);
            loadBangunanTable(diId);
            
            // 3. Render Peta Detail (Mertapada + Ciwado)
            // KITA LANGSUNG PANGGIL ID-NYA SAJA
            initDetailMap(diId);

            setTimeout(() => {
                if (detailMap) {
                    detailMap.invalidateSize();
                    console.log("✅ Peta dipaksa melek (invalidateSize)");
                }
            }, 200);
            
            // 4. Render Titik Bangunan
            // renderMarkerBangunan(diId);
            window.isAnimating = false;
        }
    });
    $("#modalBackdrop").fadeIn(300);

});

$("#closeOverlay").on("click", function() { gsap.to("#detailOverlay", { duration: 0.3, opacity: 0, display: "none" }); $("#modalBackdrop").fadeOut(300); });



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

// function renderMarkerBangunan(diId) {
//     if (!detailMap) return;
//     fetch(`/api/bangunan/${diId}/`)
//         .then(res => res.json())
//         .then(response => {
//             const data = response.data;
//             if (Array.isArray(data)) {
//                 $('#countBangunan').text(data.length + ' Unit');

//                 data.forEach(item => {
//                     if (item.latitude && item.longitude) {
//                         L.marker([item.latitude, item.longitude]).addTo(detailMap)
//                             .bindPopup(`<b>${item.nama_bangunan}</b><br>Kondisi: ${item.kondisi_aset}`);
//                     }
//                 });
//             }
//         });
// }

function initMapKeseluruhan() {
    console.log("🚩 1. Fungsi initMapKeseluruhan TERPANGGIL");
    
    if (mapKeseluruhan !== null) { 
        mapKeseluruhan.invalidateSize(); 
        return; 
    }
    
    const titikTengah = [-6.722, 108.552];
    mapKeseluruhan = L.map('map-keseluruhan', { zoomControl: false }).setView(titikTengah, 11);
    
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png').addTo(mapKeseluruhan);
    L.control.zoom({ position: 'bottomright' }).addTo(mapKeseluruhan);

    fetch('/api/daerah-irigasi/') // Sesuai dengan endpoint yang Bapak share
        .then(res => res.json())
        .then(response => {
            // Pastikan mengambil data yang HANYA is_approved: true
            const daftarDI = response.filter(di => di.is_approved === true); 
            
            if (daftarDI.length === 0) {
                console.warn("⚠️ Tidak ada data DI yang statusnya Approved!");
            }

            const filterSelect = $('#filter-di');
            filterSelect.empty().append('<option value="">-- Pilih Daerah Irigasi --</option>');
            
            daftarDI.forEach(di => {
                filterSelect.append(`<option value="${di.id}">${di.nama_di}</option>`);
                diDataMap[di.id] = di;

                const diGroup = L.featureGroup().addTo(mapKeseluruhan);
                diLayers[di.id] = diGroup;

                if (di.saluran_list && di.saluran_list.length > 0) {
                    di.saluran_list.forEach(saluran => {
                        // Cek geometry_data atau geom (di JSON Bapak ada dua-duanya)
                        const geometri = saluran.geometry_data || saluran.geom;

                        if (geometri && geometri.coordinates) {
                            L.geoJSON(geometri, {
                                style: { 
                                    color: "#2d93ad", 
                                    weight: 4,
                                    opacity: 0.8 
                                },
                                onEachFeature: function(feature, layer) {
                                    // 1. Hover Effect
                                    layer.on('mouseover', function() {
                                        this.setStyle({ color: "#ffc107", weight: 7 });
                                    });

                                    layer.on('mouseout', function() {
                                        this.setStyle({ color: "#2d93ad", weight: 4 });
                                    });

                                    // 2. Popup yang disesuaikan dengan Field JSON Bapak
                                    const popupContent = `
                                        <div style="min-width: 200px; font-family: sans-serif;">
                                            <div style="background: #0d3b66; color: white; padding: 8px; border-radius: 4px 4px 0 0; font-weight: bold; font-size: 13px;">
                                                DETAIL SALURAN
                                            </div>
                                            <div style="padding: 10px; border: 1px solid #ccc; border-top: none; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                                                <table style="width: 100%; font-size: 11px; border-collapse: collapse;">
                                                    <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>Nama</b></td><td>: ${saluran.nama_saluran}</td></tr>
                                                    <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>DI</b></td><td>: ${di.nama_di}</td></tr>
                                                    <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>Tingkat</b></td><td>: ${saluran.jaringan_tingkat || '-'}</td></tr>
                                                    <tr><td style="padding: 4px 0;"><b>Panjang</b></td><td>: ${saluran.panjang_saluran || '0'} m</td></tr>
                                                </table>
                                                <hr style="margin: 8px 0; border: 0; border-top: 1px solid #eee;">
                                                <button onclick="bukaDetailDariPeta(${di.id})" style="width: 100%; background: #007bff; color: white; border: none; padding: 5px; border-radius: 3px; cursor: pointer; font-size: 10px; font-weight: bold;">LIHAT ANALISIS</button>
                                            </div>
                                        </div>`;
                                    layer.bindPopup(popupContent);
                                }
                            }).addTo(diGroup);
                        }
                    });
                }
            });
            
            if (typeof aktifkanLogikaFilter === "function") {
                aktifkanLogikaFilter();
            }
        })
        .catch(err => console.error("❌ Error Fetch Data:", err));
}

function aktifkanLogikaFilter() {
    $('#filter-di').off('change').on('change', function() {
        const id = $(this).val();

        // --- 1. RESET SEMUA EFEK SEBELUMNYA ---
        // Kembalikan semua ke warna biru standar dan kunci dengan class 'no-blink'
        Object.values(diLayers).forEach(layerGroup => {
            layerGroup.eachLayer(function(l) {
                // Fungsi pembantu untuk reset sampai ke level terdalam
                function resetMendalam(layer) {
                    if (layer.eachLayer) {
                        layer.eachLayer(resetMendalam);
                    } else if (layer instanceof L.Path) {
                        layer.setStyle({ 
                            color: "#2d93ad", 
                            weight: 3, 
                            opacity: 0.7 
                        });
                        if (layer._path) {
                            $(layer._path).addClass('no-blink').removeClass('active-filter');
                        }
                    }
                }
                resetMendalam(l);
            });
        });

        if (!id || id === "") {
            resetMap();
            return;
        }
        
        if (id && diLayers[id]) {
            const selectedLayer = diLayers[id];
            const di = diDataMap[id]; 
            let countData = 0;

            mapKeseluruhan.closePopup();

            // --- 2. LOGIKA REKURSIF UNTUK MENYALAKAN BLINK ---
            function prosesLayer(target) {
                if (target.eachLayer) {
                    target.eachLayer(function(layer) {
                        prosesLayer(layer); // Masuk terus ke dalam grup
                    });
                } else if (target instanceof L.Path) {
                    countData++;
                    // Eksekusi Efek Visual
                    target.setStyle({ 
                        color: "#ffc107", 
                        weight: 10, 
                        opacity: 1 
                    });
                    
                    if (target._path) {
                        // Cabut penahan 'no-blink' agar animasi CSS menyala
                        $(target._path).removeClass('no-blink').addClass('active-filter');
                    }
                }
            }

            // Jalankan pencarian dan aktivasi
            prosesLayer(selectedLayer);

            console.log(`%c 🔎 FILTER TERPILIH: ${di.nama_di} `, 'background: #0d3b66; color: #fff; font-weight: bold;');
            console.log(`📊 Jumlah Saluran (Ditemukan secara Rekursif): ${countData}`);

            if (countData === 0) {
                console.error("❌ Data saluran tidak ditemukan di dalam diLayers[" + id + "]");
            }

            // --- 3. TERBANG KE LOKASI ---
            const bounds = selectedLayer.getBounds();
            mapKeseluruhan.flyToBounds(bounds, { 
                padding: [50, 50], 
                duration: 1.5 
            });

            // --- 4. POPUP & RE-APPLY SETELAH TIBA ---
            mapKeseluruhan.once('moveend', function() {
                // Pastikan class tetap nempel setelah render ulang flyTo
                prosesLayer(selectedLayer);

                tampilkanInfoDI(di, selectedLayer);
                
                setTimeout(() => {
                    const center = selectedLayer.getBounds().getCenter();
                    const statusBadge = di.is_pai_verified ? '<span class="badge bg-success">PAI Complete</span>' : '<span class="badge bg-secondary">PAI Pending</span>';
                    const iksiBadge = di.is_iksi_calculated ? '<span class="badge bg-info">IKSI Ready</span>' : '<span class="badge bg-light text-dark border">IKSI Pending</span>';
                    
                    const popupContent = `
                        <div class="custom-popup" style="width:200px">
                            <div class="popup-header p-2 rounded-top text-center" style="background-color: #0d3b66; color: white;">
                                <h6 class="m-0 small fw-bold">${di.nama_di}</h6>
                            </div>
                            <div class="popup-body p-2 border border-top-0 rounded-bottom bg-white shadow-sm text-center">
                                <div class="mb-2">${statusBadge} ${iksiBadge}</div>
                                <p class="small mb-2 text-dark">Luas Fungsional: <b>${di.luas_fungsional} Ha</b></p>
                                <button class="btn btn-sm w-100 text-white" style="font-size: 10px; background-color: #2d93ad;" 
                                    onclick="bukaDetailDariPeta(${di.id})">DETAIL ANALISIS</button>
                            </div>
                        </div>`;

                    L.popup({ minWidth: 180, closeOnClick: false })
                        .setLatLng(center)
                        .setContent(popupContent)
                        .openOn(mapKeseluruhan);
                }, 300);
            });

        } else {
            resetMap();
        }
    });
}

function resetMap() {
    if (!mapKeseluruhan) return;
    
    // Kembalikan warna semua saluran ke biru standar dan matikan blink
    Object.values(diLayers).forEach(layerGroup => {
        layerGroup.eachLayer(function(layer) {
            if (layer instanceof L.Path) {
                layer.setStyle({ color: "#2d93ad", weight: 3, opacity: 1 });
                if (layer._path) $(layer._path).removeClass('blinking-canal');
            }
        });
    });

    $('#peta-info-box').fadeOut(300);
    $('#filter-di').val(""); 
    mapKeseluruhan.closePopup();
    mapKeseluruhan.flyTo([-6.722, 108.552], 11, { animate: true, duration: 1.2 });
}

function tampilkanInfoDI(di, layer) {
    $('#peta-info-box').stop().fadeIn(300);
    $('#info-nama-di').text(di.nama_di);
    const badgeHtml = di.is_pai_verified ? '<span class="badge bg-success small">PAI Terverifikasi</span>' : '<span class="badge bg-secondary small">PAI Belum Terdata</span>';
    $('#info-saluran').text(di.jml_saluran || 0);
    $('#info-bangunan').text(di.jml_bangunan || 0);
    $('#info-kewenangan').text(di.kewenangan || "Kabupaten Cirebon");
    $('#info-status-pai').html(badgeHtml);
    
    const btnSkema = $('#btn-download-skema');
    if (di.geojson_url) { btnSkema.attr('href', di.geojson_url).show(); } else { btnSkema.hide(); }
}

function bukaDetailDariPeta(id) {
    // 1. Pindahkan Tab ke "Tabel Data"
    const tabTrigger = document.querySelector('#table-tab');
    if (tabTrigger) bootstrap.Tab.getOrCreateInstance(tabTrigger).show();

    // 2. Klik link detail
    setTimeout(() => {
        const targetLink = $(`.view-detail[data-id="${id}"]`);
        if (targetLink.length > 0) { targetLink.click(); }
        else { $('#id_di_aktif').val(id); console.log("Data tidak ditemukan di halaman tabel saat ini."); }
    }, 300);
}



// Pasang event kliknya
$(document).on('click', '#close-info-btn, #reset-map-btn', function() {
    resetMap();
});

setTimeout(() => {
    initMapKeseluruhan();
}, 500);

// 2. Trigger saat user pindah-pindah tab secara manual
$('button[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
    let target = $(e.target).attr("id");
    if (target === 'stats-tab') {
        initMapKeseluruhan();
    }
});

function showDetailPaiIksi(asetId, namaAset) {
    // 1. Cari data objek bangunan/titik dari array global
    const dataAset = window.currentBangunanData.find(a => a.id === asetId);
    
    if (!dataAset) {
        console.error("Data aset tidak ditemukan!");
        return;
    }

    // 2. Identifikasi apakah ini Bangunan atau Saluran
    // (Asumsi: Bangunan memiliki kode aset seperti B01, B02, P01, dll)
    const isBangunan = dataAset.kode_aset && (dataAset.kode_aset.startsWith('B') || dataAset.kode_aset.startsWith('P'));

    $('#pai-di-nama').text(`${dataAset.nama_saluran || '-'} / ${dataAset.luas_areal || 0} Ha`);
    
    // Update Baris Tabel
    $('#pai-jenis').text(dataAset.kode_aset || '-');
    $('#pai-nama').text(dataAset.nama_aset_manual || '-');
    $('#pai-nomenklatur').text(dataAset.nomenklatur_ruas || '-');
    $('#pai-saluran').text(dataAset.nama_saluran || '-');


    // 3. Isi Header Info IKSI Bangunan
    $('#iksi-nama-aset').text(dataAset.nama_aset_manual || '-');
    $('#iksi-nomenklatur').text(dataAset.nomenklatur_ruas || '-');
    $('#iksi-tahun').text('2023'); // Tahun survey dari data input

    // Logika Surveyor: Hanya muncul jika ini data Bangunan
    if (isBangunan) {
        // Ambil field surveyor dari model TitikIrigasi yang dikirim lewat API
        $('#iksi-surveyor').text(dataAset.surveyor || 'Surveyor e-PAKSI');
    } else {
        $('#iksi-surveyor').text('-'); // Kosongkan jika Saluran
    }

    if (dataAset.foto_aset) {
        // Jika API mengirimkan path gambar
        $('#pai-foto').html(`<img src="${dataAset.foto_aset}" class="img-fluid rounded shadow-sm" style="max-height: 200px; border: 1px solid #dee2e6;">`);
    } else {
        $('#pai-foto').html('<em class="text-muted"><i class="fa-solid fa-image-slash me-1"></i>Tidak ada foto</em>');
    }

    if (dataAset.latitude && dataAset.latitude !== 0) {
        const geoJsonObj = {
            "type": "Point",
            "coordinates": [dataAset.longitude, dataAset.latitude]
        };
        $('#pai-geojson').text(JSON.stringify(geoJsonObj));
    } else {
        $('#pai-geojson').text('{"type":"Point","coordinates":[0,0]}');
    }

    $('#pai-catatan').text(dataAset.keterangan || '-');

    // 6. Navigasi Otomatis ke Tab PAI
    // Kita cari button pemicu tab-pai dan aktifkan
    const tabTrigger = document.querySelector('button[data-bs-target="#tab-pai"]');
    if (tabTrigger) {
        const tab = new bootstrap.Tab(tabTrigger);
        tab.show();
    } else {
        // Fallback jika menggunakan ID tab langsung
        $('[data-bs-target="#tab-pai"]').tab('show');
    }

    document.getElementById('tab-pai').scrollIntoView({ 
        behavior: 'smooth', 
        block: 'start' 
    });




    // 4. Render Foto Bangunan
    renderPhotos(dataAset);

    // 5. Jalankan Pengisian Tabel IKSI Khusus Bangunan
    renderTabelIksiBangunan(dataAset);
    
    // Tampilkan Modal
    const modal = bootstrap.Modal.getOrCreateInstance('#modalAsetDetail');
    modal.show();
}

function renderPhotos(data) {
    let photoHtml = '';
    // Mengacu pada model DetailLayananBangunan field: foto_aset
    if (data.foto_aset) {
        photoHtml = `
            <div class="photo-card">
                <img src="${data.foto_aset}" class="img-thumbnail shadow-sm" 
                     style="width:140px; height:100px; object-fit:cover; cursor:pointer;" 
                     onclick="window.open('${data.foto_aset}')">
                <div class="text-center mt-1 fw-bold small">Foto Kondisi</div>
            </div>
        `;
    } else {
        photoHtml = '<div class="alert alert-light border small w-100">Belum ada foto survey</div>';
    }
    $('#iksi-photos-container').html(photoHtml);
}

function loadIksiDataTable(dataAset) {
    // Hancurkan datatable lama jika sudah ada
    if ($.fn.DataTable.isDataTable('#tabelIksiAset')) {
        $('#tabelIksiAset').DataTable().destroy();
    }

    // Siapkan data dummy/statis berdasarkan dataAset yang diklik
    // Di sini Anda bisa memetakan data dari API Anda nantinya
    const dataset = [
        {
            "kode": dataAset.kode_aset,
            "komponen": dataAset.nama_aset_manual,
            "kondisi": dataAset.pintu_rusak_berat > 0 ? "Rusak Berat" : "Baik",
            "nilai": dataAset.pintu_rusak_berat > 0 ? 30 : 85,
            "bobot": "100%",
            "akhir": dataAset.pintu_rusak_berat > 0 ? 30 : 85,
            "final": "85%"
        },
        {
            "kode": dataAset.kode_aset + "_01",
            "komponen": "Fisik Bangunan",
            "kondisi": "Sedang",
            "nilai": 70,
            "bobot": "50%",
            "akhir": 35,
            "final": "-"
        }
    ];

    $('#tabelIksiAset').DataTable({
        data: dataset,
        columns: [
            { data: 'kode', className: 'fw-bold' },
            { data: 'komponen' },
            { data: 'kondisi', render: d => `<span class="badge ${d === 'Baik' ? 'bg-success' : 'bg-danger'}">${d}</span>` },
            { data: 'nilai', className: 'text-center' },
            { data: 'bobot', className: 'text-center' },
            { data: 'akhir', className: 'text-center' },
            { data: 'final', className: 'text-center fw-bold' }
        ],
        dom: 't', // Hanya tampilkan tabel (tanpa search/paging agar ringkas di modal)
        paging: false,
        ordering: false,
        language: { emptyTable: "Data IKSI belum tersedia" }
    });
}


function renderTabelIksiBangunan(data) {
    const container = $('#body-iksi-detail');
    container.empty();
    
    const kode = data.kode_aset || 'B01';
    
    // Layout Kuisioner Bangunan (Contoh Bendung/Pintu)
    let html = `
        <tr class="table-warning fw-bold">
            <td>${kode}</td>
            <td>${(data.nama_aset_manual || 'BANGUNAN UTAMA').toUpperCase()}</td>
            <td>-</td><td>-</td><td>-</td><td>-</td>
            <td class="text-center">9.42</td>
            <td class="text-center">9.42</td>
            <td class="text-center">72.46%</td>
        </tr>
        <tr>
            <td>${kode}_01</td>
            <td>Pintu Air & Roda Gigi</td>
            <td class="text-center">Baik</td>
            <td class="text-center">${data.pintu_baik}</td>
            <td class="text-center">100</td>
            <td class="text-center">${data.pintu_baik > 0 ? 85 : 0}</td>
            <td></td><td></td><td></td>
        </tr>
    `;
    container.append(html);
}

// Ambil ID DI yang sedang aktif dari hidden input atau variable global
function getActiveDiId() {
    return $('#id_di_aktif').val(); 
}

function rekapAset() {
    // Ambil ID DI yang sedang aktif dari input hidden yang ada di overlay
    const diId = $('#id_di_aktif').val(); 
    
    if (!diId) {
        alert("Silakan pilih Daerah Irigasi terlebih dahulu.");
        return;
    }

    // Buka laporan di tab baru
    const url = `/laporan/rekap-aset/${diId}/`;
    window.open(url, '_blank');
}

function iksiGabungan() {
    const id = getActiveDiId();
    if(!id) return alert("Pilih Daerah Irigasi terlebih dahulu");
    
    // Sesuai dengan dokumen "IKSI GABUNGAN 1.pdf" yang Anda upload
    window.open(`/laporan/iksi-gabungan/${id}/`, '_blank');
}