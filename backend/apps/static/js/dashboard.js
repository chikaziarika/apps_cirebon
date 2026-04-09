
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
// let detailMap = null;    
let mapKeseluruhan = null;  
let diLayers = {};
let diDataMap = {};
let currentView = 'permen';

// DataTable Instance (GLOBAL AGAR BISA DIAKSES EVENT LISTENER)
var tableBangunanInstance = null;

window.panelDataOriginal = { primer: [], sekunder: [], tersier: [], bangunan: [] };
window.panelDataFiltered = { primer: [], sekunder: [], tersier: [], bangunan: [] };
window.panelPage = { primer: 1, sekunder: 1, tersier: 1, bangunan: 1 };
window.dictLayerSaluran = {}; 
window.dictLayerBangunan = {}; 
window.currentActiveSegments = null;
window.currentActiveSaluranId = null;

window.renderPanelList = function(kategori) {
    const items = window.panelDataFiltered[kategori] || [];
    const page = window.panelPage[kategori] || 1;
    const perPage = 5; 
    const totalPages = Math.ceil(items.length / perPage) || 1;

    // 1. Jika data kosong, langsung tampilkan teks & hentikan proses
    if (items.length === 0) {
        $(`#list-map-${kategori}`).html(`<div class="p-3 text-center text-muted small" style="margin-top: 2rem;"><i>Data tidak ditemukan</i></div>`);
        $(`#pag-${kategori}`).html(''); 
        return; // Mencegah error lanjutan
    }

    // 2. Jika ada data, potong sesuai halaman
    const start = (page - 1) * perPage;
    const end = start + perPage;
    const sliced = items.slice(start, end);

    let htmlList = sliced.map(item => item.html).join('');
    $(`#list-map-${kategori}`).html(htmlList);

    let pagHtml = `
        <div style="font-size:9px;">Total: <b>${items.length}</b></div>
        <div>
            <button class="pagination-btn" onclick="window.gantiPagePanel('${kategori}', -1)" ${page <= 1 ? 'disabled' : ''}><i class="fa-solid fa-chevron-left"></i></button>
            <span class="mx-1 fw-bold">Hal ${page}/${totalPages}</span>
            <button class="pagination-btn" onclick="window.gantiPagePanel('${kategori}', 1)" ${page >= totalPages ? 'disabled' : ''}><i class="fa-solid fa-chevron-right"></i></button>
        </div>
    `;
    $(`#pag-${kategori}`).html(pagHtml);
};

window.gantiPagePanel = function(kategori, arah) {
    window.panelPage[kategori] += arah;
    window.renderPanelList(kategori);
};

window.activeBlinkPolygon = null;
window.activeBlinkMarker = null;

// Fungsi untuk mematikan semua kedipan
// ==========================================
// 1. FUNGSI MATIKAN KEDIPAN (UPDATE)
// ==========================================
function matikanSemuaKedipan() {
    // Reset Poligon
    if (window.activeBlinkPolygon) {
        const domPath = window.activeBlinkPolygon.getElement();
        if (domPath) {
            domPath.classList.remove('polygon-blink');
        }
        window.activeBlinkPolygon = null;
    }
    // Reset Marker
    if (window.activeBlinkMarker) {
        if (window.activeBlinkMarker._icon) {
            window.activeBlinkMarker._icon.classList.remove('marker-blink');
        }
        window.activeBlinkMarker = null;
    }
}



function hideAllDetails() {
    $("#view-ringkasan, #view-drilldown, #view-detail-luas, #view-detail-distribusi, #view-detail-sebaran, #view-detail-di, #section-list-saluran").hide();
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

    // 1. Animasi menghilang halus pada container aktif
    gsap.to(".container-fluid", { 
        duration: 0.3, 
        opacity: 0, 
        ease: "power2.inOut",
        onComplete: () => {
            hideAllDetails();
            
            // 2. Siapkan tampilan awal
            $("#view-detail-di").show(); 
            
            // 3. Scroll ke atas secara instan tanpa animasi (agar tidak terlihat "lompat")
            $("#main-content").scrollTop(0); 

            // 4. Munculkan kembali dengan halus
            gsap.to(".container-fluid", { 
                duration: 0.4, 
                opacity: 1, 
                ease: "power2.out" 
            });
            
            // Inisialisasi ulang tabel jika perlu
            if ($.fn.DataTable.isDataTable('#tableDrillDI')) {
                $('#tableDrillDI').DataTable().columns.adjust();
            }
        }
    });
}

// =========================================================
// 3. LOGIKA CARD CLICK / DRILLDOWN (SUPORT AUTO-SWITCH)
// =========================================================

function showDrillDownJaringan() { 
    $("#main-content").css("overflow", "hidden");
    
    // Gunakan filter blur tipis saat transisi agar transisi terlihat elegan, bukan berkedip
    gsap.to(".container-fluid", { 
        duration: 0.3, 
        opacity: 0, 
        filter: "blur(5px)", 
        ease: "power2.inOut",
        onComplete: () => {
            hideAllDetails();
            
            const $target = $("#view-drilldown");
            $target.show().css({
                "opacity": 0,
                "display": "block"
            });

            // Pastikan data chart siap sebelum di-render
            setTimeout(() => {
                renderSubDetailCharts();
                
                // Munculkan container baru dengan fade in + hilangkan blur
                gsap.to(".container-fluid", { 
                    duration: 0.4, 
                    opacity: 1, 
                    filter: "blur(0px)",
                    ease: "power2.out" 
                });
            }, 50); // Jeda 50ms untuk stabilitas DOM
        }
    });
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

function initAllTooltips() {
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        // Hapus instance lama agar tidak double
        var oldTooltip = bootstrap.Tooltip.getInstance(tooltipTriggerEl);
        if (oldTooltip) oldTooltip.dispose();
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

// Tambahkan juga pada saat DataTable berpindah halaman
$('#table-saluran-master').on('draw.dt', function() {
    initAllTooltips();
});


function showDrillDownSebaran() {
    // 1. Kunci scroll
    $("#main-content").css("overflow", "hidden"); 
    
    // 2. Animasi keluar container lama
    gsap.to(".container-fluid", { 
        duration: 0.3, 
        opacity: 0, 
        y: -10, // Tambah efek gerak dikit biar keren
        ease: "power2.inOut",
        onComplete: () => {
            // 3. Sembunyikan semua section lain
            hideAllDetails(); 
            
            // 4. Siapkan section target
            const $target = $("#section-list-saluran");
            $target.css({ "display": "block", "opacity": 0 }); 

            const $analisisSebaran = $("#view-detail-sebaran");
            $analisisSebaran.show().css({ "opacity": 1, "display": "block" });

            // 5. Animasi masuk kembali
            gsap.to(".container-fluid", { 
                duration: 0.4, 
                opacity: 1, 
                y: 0,
                ease: "power2.out",
                onComplete: () => {
                    // 6. Paksa opacity target ke 1 (Jaga-jaga jika tertahan di 0)
                    $target.animate({ opacity: 1 }, 200);

                    // 7. Refresh DataTable & Charts
                    if ($.fn.DataTable.isDataTable('#table-saluran-master')) {
                        $('#table-saluran-master').DataTable().columns.adjust().draw();
                    }
                    
                    // PANGGIL ULANG fungsi render chart sebaran jika ada
                    if (typeof renderKeandalanChart === "function") {
                        // Pastikan data tersedia atau panggil fungsi render yang ada di script kamu
                        // renderKeandalanChart(); 
                    }
                }
            });
        }
    });
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

    hideAllDetails();
    $("#view-detail-di").show().css("opacity", 1);

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
        if (targetId === 'modal-bangunan-tab') {
            if (window.currentFilterSaluran) {
                loadBangunanTable(diId, window.currentFilterId, window.currentFilterSaluran);
            } else {
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

// function renderChartsDetailLuas() {
//     const labels = []; const dataBaku = []; const dataFungsional = [];
//     window.dataIrigasiFull.slice(0, 10).forEach(di => { labels.push(di.nama_di); dataBaku.push(di.luas_baku_permen); dataFungsional.push(di.luas_fungsional); });
//     if (chartDetailLuasBarObj) chartDetailLuasBarObj.destroy();
//     chartDetailLuasBarObj = new Chart(document.getElementById('chartDetailLuasBar').getContext('2d'), {
//         type: 'bar', data: { labels: labels, datasets: [{ label: 'Luas Baku', data: dataBaku, backgroundColor: '#6c757d' }, { label: 'Luas Fungsional', data: dataFungsional, backgroundColor: '#198754' }] },
//         options: { responsive: true, maintainAspectRatio: false }
//     });
//     if (chartDetailLuasPieObj) chartDetailLuasPieObj.destroy();
//     chartDetailLuasPieObj = new Chart(document.getElementById('chartDetailLuasPie').getContext('2d'), {
//         type: 'pie', data: { labels: ['Terairi', 'Belum Terairi'], datasets: [{ data: [window.dataLuas.fungsional, window.dataLuas.baku_permen - window.dataLuas.fungsional], backgroundColor: ['#198754', '#e9ecef'] }] },
//         options: { maintainAspectRatio: false }
//     });
// }

let currentFilterLuas = 'top10_rendah'; // Default

// Fungsi yang dipanggil saat dropdown berubah
function applyLuasFilter(mode) {
    currentFilterLuas = mode;
    renderChartsDetailLuas(); // Gambar ulang chart dengan data baru
}

// Fungsi untuk mode Layar Penuh (Fullscreen)
function toggleFullScreen(elementId) {
    const elem = document.getElementById(elementId);
    if (!document.fullscreenElement) {
        elem.requestFullscreen().catch(err => {
            alert(`Error: Tidak bisa fullscreen. ${err.message}`);
        });
    } else {
        document.exitFullscreen();
    }
}

// --- FUNGSI UTAMA PENGGAMBARAN CHART ---
function renderChartsDetailLuas() {
    // KITA GANTI window.dataIrigasiFull DENGAN FETCH API LANGSUNG
    fetch('/api/daerah-irigasi/')
        .then(res => res.json())
        .then(response => {
            // Antisipasi format respons dari DRF
            let dataApi = Array.isArray(response) ? response : response.data;
            if (!dataApi || dataApi.length === 0) return;

            const labels = []; 
            const dataBatasMaksimal = []; 
            const dataFungsional = [];

            // 1. Data untuk Bar Chart
            let chartData = [...dataApi];
            chartData.sort((a, b) => {
                let persenA = a.luas_baku_permen > 0 ? (a.luas_fungsional / a.luas_baku_permen) : 0;
                let persenB = b.luas_baku_permen > 0 ? (b.luas_fungsional / b.luas_baku_permen) : 0;
                return persenA - persenB;
            });

            // Pastikan currentFilterLuas terdefinisi agar tidak error
            if (typeof currentFilterLuas !== 'undefined' && currentFilterLuas === 'top10_rendah') {
                chartData = chartData.slice(0, 10);
            }

            chartData.forEach(di => { 
                labels.push(di.nama_di); 
                dataBatasMaksimal.push(parseFloat(di.luas_baku_permen) || 0); 
                dataFungsional.push(parseFloat(di.luas_fungsional) || 0); 
            });

            // Render Bar Chart
            const ctxBar = document.getElementById('chartDetailLuasBar');
            if (ctxBar) {
                if (window.chartDetailLuasBarObj) window.chartDetailLuasBarObj.destroy();
                window.chartDetailLuasBarObj = new Chart(ctxBar.getContext('2d'), {
                    data: { 
                        labels: labels, 
                        datasets: [
                            { 
                                type: 'line', label: 'Luas Baku (Target Maksimal)', 
                                data: dataBatasMaksimal, borderColor: '#e74a3b', backgroundColor: '#e74a3b',
                                borderWidth: 2, borderDash: [5, 5], pointRadius: 4, fill: false, order: 1,
                                datalabels: { align: 'end', anchor: 'end', offset: 6, color: '#e74a3b', font: { weight: 'bold', size: 11 } }
                            },
                            { 
                                type: 'bar', label: 'Luas Fungsional (Realisasi)', 
                                data: dataFungsional, backgroundColor: '#1cc88a', borderRadius: 4, order: 2,
                                datalabels: { align: 'center', anchor: 'center', color: '#ffffff', font: { weight: 'bold', size: 11 } }
                            }
                        ] 
                    },
                    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } }, scales: { y: { beginAtZero: true } } }
                });
            }

            // ==============================================================
            // 2. CHART PIE PROPORSI AREA (PERMEN PU & ONEMAP) MENGGUNAKAN API
            // ==============================================================
            
            function createLuasPieChart(canvasId, totalFungsional, totalBaku, tipeBaku) {
                const ctxPie = document.getElementById(canvasId);
                if (!ctxPie) return null;

                let belumTerairi = Math.max(0, totalBaku - totalFungsional);
                let dataPie = [totalFungsional, belumTerairi];

                return new Chart(ctxPie.getContext('2d'), {
                    type: 'pie',
                    data: {
                        labels: ['Terairi (Fungsional)', 'Belum Terairi/Hilang'],
                        datasets: [{
                            data: dataPie,
                            backgroundColor: ['#1cc88a', '#e9ecef'],
                            borderWidth: 1
                        }]
                    },
                    options: {
                        maintainAspectRatio: false,
                        plugins: {
                            legend: { position: 'bottom' },
                            tooltip: {
                                callbacks: {
                                    label: function(context) {
                                        let valStr = context.raw.toLocaleString('id-ID');
                                        let fungsionalStr = totalFungsional.toLocaleString('id-ID');
                                        let bakuStr = totalBaku.toLocaleString('id-ID');
                                        let pct = totalBaku > 0 ? ((context.raw / totalBaku) * 100).toFixed(1) : 0;
                                        
                                        if (context.dataIndex === 0) { // Hover Hijau
                                            return ` Luas Fungsional: ${fungsionalStr} Ha | Berdasarkan ${tipeBaku}: ${bakuStr} Ha (${pct}%)`;
                                        } else { // Hover Abu-abu
                                            return ` Belum Terairi: ${valStr} Ha | Berdasarkan ${tipeBaku}: ${bakuStr} Ha (${pct}%)`;
                                        }
                                    }
                                }
                            },
                            datalabels: {
                                color: (context) => context.dataIndex === 0 ? '#fff' : '#6c757d', 
                                font: { weight: 'bold', size: 12 },
                                formatter: (value, ctx) => {
                                    if (value === 0 || totalBaku === 0) return '';
                                    return (value * 100 / totalBaku).toFixed(1) + "%";
                                }
                            }
                        }
                    }
                });
            }

            // Hitung Ulang Total Berdasarkan Data Segar dari API
            let globalFungsional = 0;
            let globalBakuPermen = 0;
            let globalBakuOnemap = 0;

            dataApi.forEach(di => {
                globalFungsional += parseFloat(di.luas_fungsional) || 0;
                globalBakuPermen += parseFloat(di.luas_baku_permen) || 0;
                globalBakuOnemap += parseFloat(di.luas_baku_onemap) || 0;
            });

            // Hancurkan chart lama jika ada
            if (window.chartLuasPiePermenObj) window.chartLuasPiePermenObj.destroy();
            if (window.chartLuasPieOneMapObj) window.chartLuasPieOneMapObj.destroy();

            // Render Chart Pie Baru
            window.chartLuasPiePermenObj = createLuasPieChart('chartDetailLuasPiePermen', globalFungsional, globalBakuPermen, "Permen PU");
            window.chartLuasPieOneMapObj = createLuasPieChart('chartDetailLuasPieOneMap', globalFungsional, globalBakuOnemap, "OneMap");
            
        })
        .catch(err => console.error("Gagal menarik data untuk Chart Bar & Pie:", err));
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




    function initBangunanTable() {
        if ($.fn.DataTable.isDataTable('#tabelBangunan')) {
            $('#tabelBangunan').DataTable().destroy();
        }

        $('#tabelBangunan').DataTable({
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
            sumber_air: el.data('sumber_air') || "-",
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

            tersier_baik: parseFloat(el.data('t_baik')) || 0,
            tersier_rr: parseFloat(el.data('t_rr')) || 0,
            tersier_rb: parseFloat(el.data('t_rb')) || 0,
            tersier_bap: parseFloat(el.data('t_bap')) || 0,

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

    let pPrimer = parseFloat(d.panjang_primer) || 0;
    let pSekunder = parseFloat(d.panjang_sekunder) || 0;
    let pTersier = parseFloat(d.panjang_tersier) || 0;

    let totalPanjang = pPrimer + pSekunder + pTersier;

    $('#countPrimer').text(pPrimer.toLocaleString('id-ID') + ' m');
    $('#countSekunder').text(pSekunder.toLocaleString('id-ID') + ' m');
    $('#countTersier').text(pTersier.toLocaleString('id-ID') + ' m');
    $('#countTotalSal').text(totalPanjang.toLocaleString('id-ID') + ' m');
    $('#countBangunan').text(d.jml_bangunan);
    let jmlPintu = parseInt(d.jumlah_pintu) || parseInt(d.jml_pintu) || 0;
    $('#countPintu').text(jmlPintu + ' Unit');
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
            // Cukup terbang ke lokasi (flyTo) tanpa membuat marker baru yang dobel
            detailMap.flyTo([lat, lon], 19, { animate: true, duration: 1.5 });
        }
    }, 400);
}


let layerBangunanGroup = L.featureGroup();
let layerPendukungGroup = L.featureGroup();

function initMapKeseluruhan() {
    console.log("🚩 1. Fungsi initMapKeseluruhan TERPANGGIL");

    if (mapKeseluruhan !== null) { 
        mapKeseluruhan.invalidateSize(); 
        return; 
    }
    
    const titikTengah = [-6.7641, 108.4789];
    mapKeseluruhan = L.map('map-keseluruhan', { zoomControl: false }).setView(titikTengah, 13);

    mapKeseluruhan.on('popupclose', function() {
        if (typeof matikanSemuaKedipan === "function") matikanSemuaKedipan();
    });
    mapKeseluruhan.on('click', function() {
        if (typeof matikanSemuaKedipan === "function") matikanSemuaKedipan();
    });

    mapKeseluruhan.createPane('paneWilayah');
    mapKeseluruhan.getPane('paneWilayah').style.zIndex = 330;

    mapKeseluruhan.createPane('paneLahan');
    mapKeseluruhan.getPane('paneLahan').style.zIndex = 340;

    mapKeseluruhan.createPane('panePendukung');
    mapKeseluruhan.getPane('panePendukung').style.zIndex = 350;

    mapKeseluruhan.createPane('paneSaluran');
    mapKeseluruhan.getPane('paneSaluran').style.zIndex = 600;

    mapKeseluruhan.createPane('paneBangunan');
    mapKeseluruhan.getPane('paneBangunan').style.zIndex = 650;

    const baseMaps = {
        "Peta Dasar (Terang)": L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
        "Peta Satelit": L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
    };
    
    let grupKategori = {
        'wilayah': L.featureGroup(),
        'jalan': L.featureGroup(),
        'irigasi': L.featureGroup(),
        'lahan': L.featureGroup(), 
        'air': L.featureGroup()
    };

    const overlayMaps = {
        "<i class='fa-solid fa-location-dot text-danger'></i> Aset Bangunan": layerBangunanGroup,
        "<i class='fa-solid fa-draw-polygon text-success'></i> Luas Fungsional": grupKategori['lahan'],
        "<i class='fa-solid fa-road text-dark'></i> Jaringan Jalan": grupKategori['jalan'],
        "<i class='fa-solid fa-map text-secondary'></i> Batas Wilayah": grupKategori['wilayah'],
        "<i class='fa-solid fa-water text-info'></i> Sumber Air/Waduk": grupKategori['air']
    };

    L.control.layers(baseMaps, overlayMaps, { collapsed: false }).addTo(mapKeseluruhan);
    if (L.control.browserPrint) {
        L.control.browserPrint({
            title: 'Cetak Laporan Peta',
            printModesNames: { 
                Portrait: 'Potrait', 
                Landscape: 'Lanskap', 
                Auto: 'Otomatis', 
                Custom: 'Pilih Area' 
            }
        }).addTo(mapKeseluruhan);
    } else {
        console.error("Library Leaflet Browser Print belum terload sempurna!");
    }
    L.control.zoom({ position: 'bottomright' }).addTo(mapKeseluruhan);
    
    Object.values(grupKategori).forEach(group => group.addTo(mapKeseluruhan));
    layerBangunanGroup.addTo(mapKeseluruhan);
    layerPendukungGroup.addTo(mapKeseluruhan);

    const centerControl = L.Control.extend({
        options: { position: 'topright' },
        onAdd: function() {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control leaflet-control-custom');
            container.innerHTML = '<i class="fa-solid fa-house-chimney"></i>';
            container.title = "Kembali ke Posisi Awal";
            
            container.onclick = function() {
                mapKeseluruhan.flyTo(titikTengah, 13, { duration: 1.5, easeLinearity: 0.25 });
                $('#filter-di').val("").trigger('change');
            };
            return container;
        }
    });
    mapKeseluruhan.addControl(new centerControl());

    const fullscreenControl = L.Control.extend({
        options: { position: 'topright' },
        onAdd: function() {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control leaflet-control-custom');
            container.innerHTML = '<i class="fa-solid fa-expand"></i>';
            container.title = "Mode Layar Penuh";
            
            container.onclick = function() {
                const mapId = document.getElementById('map-keseluruhan');
                if (!document.fullscreenElement) {
                    mapId.requestFullscreen().catch(err => { alert(`Error: ${err.message}`); });
                    container.innerHTML = '<i class="fa-solid fa-compress"></i>';
                } else {
                    document.exitFullscreen();
                    container.innerHTML = '<i class="fa-solid fa-expand"></i>';
                }
            };
            return container;
        }
    });
    mapKeseluruhan.addControl(new fullscreenControl());

    const ListAsetControl = L.Control.extend({
        options: { position: 'topleft' },
        onAdd: function() {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control custom-map-panel');
            L.DomEvent.disableClickPropagation(container);
            L.DomEvent.disableScrollPropagation(container);

            container.innerHTML = `
                <div class="d-flex justify-content-between align-items-center" id="btn-toggle-panel" style="cursor: pointer; padding-bottom: 4px; border-bottom: 1px solid #eee;">
                    <h6 class="fw-bold mb-0 text-primary" style="font-size:0.85rem;">
                        <i class="fa-solid fa-list me-1"></i> Data Aset Peta
                    </h6>
                    <i class="fa-solid fa-chevron-up text-secondary" id="icon-toggle-panel" style="transition: transform 0.3s ease;"></i>
                </div>
                
                <div id="panel-aset-body" style="padding-top: 8px;">
                    <input type="text" id="map-search-input" class="form-control form-control-sm mb-2" placeholder="Cari aset di sini...">
                    
                    <div class="row g-1 mb-2">
                        <div class="col-6">
                            <select id="map-filter-kondisi" class="form-select form-select-sm text-secondary" style="font-size: 0.7rem;">
                                <option value="ALL">Semua Kondisi</option>
                                <option value="BAIK">Kondisi: BAIK</option>
                                <option value="RR">Kondisi: R. RINGAN</option>
                                <option value="RB">Kondisi: R. BERAT</option>
                                <option value="BAP">Kondisi: BAP</option>
                            </select>
                        </div>
                        <div class="col-6">
                            <select id="map-sort-data" class="form-select form-select-sm text-secondary" style="font-size: 0.7rem;">
                                <option value="DEFAULT">Urutkan Default</option>
                                <option value="RB_FIRST">Paling Rusak Dulu</option>
                                <option value="BAIK_FIRST">Paling Bagus Dulu</option>
                                <option value="NAMA_ASC">Sesuai Abjad (A-Z)</option>
                            </select>
                        </div>
                    </div>
                    <ul class="nav nav-pills nav-justified mb-2" style="font-size: 0.65rem;">
                        <li class="nav-item"><a class="nav-link active py-1 px-0 panel-tab-btn" href="#tab-map-primer">Primer</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 panel-tab-btn" href="#tab-map-sekunder">Sekunder</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 panel-tab-btn" href="#tab-map-tersier">Tersier</a></li>
                        <li class="nav-item"><a class="nav-link py-1 px-0 panel-tab-btn" href="#tab-map-bangunan">Bangunan</a></li>
                    </ul>
                    
                    <div class="tab-content" style="flex-grow: 1; overflow: hidden; display: flex; flex-direction: column;">
                        <div class="panel-tab-content" id="tab-map-primer" style="display:block; height:100%; overflow-y:auto;">
                            <div class="list-group list-group-flush" id="list-map-primer"></div>
                            <div class="pagination-container" id="pag-primer"></div>
                        </div>
                        <div class="panel-tab-content" id="tab-map-sekunder" style="display:none; height:100%; overflow-y:auto;">
                            <div class="list-group list-group-flush" id="list-map-sekunder"></div>
                            <div class="pagination-container" id="pag-sekunder"></div>
                        </div>
                        <div class="panel-tab-content" id="tab-map-tersier" style="display:none; height:100%; overflow-y:auto;">
                            <div class="list-group list-group-flush" id="list-map-tersier"></div>
                            <div class="pagination-container" id="pag-tersier"></div>
                        </div>
                        <div class="panel-tab-content" id="tab-map-bangunan" style="display:none; height:100%; overflow-y:auto;">
                            <div class="list-group list-group-flush" id="list-map-bangunan"></div>
                            <div class="pagination-container" id="pag-bangunan"></div>
                        </div>
                    </div>
                </div>
            `;
            return container;
        }
    });
    mapKeseluruhan.addControl(new ListAsetControl());

// =======================================================
// FUNGSI GABUNGAN: SEARCH + FILTER + SORT PANEL PETA
// =======================================================
function updatePanelFilter() {
    let keyword = $('#map-search-input').val().toLowerCase();
    let kondisiFilter = $('#map-filter-kondisi').val();
    let sortBy = $('#map-sort-data').val();
    
    // Ambil tab mana yang sedang aktif (primer, sekunder, tersier, atau bangunan)
    let activeTabHref = $('.custom-map-panel .panel-tab-btn.active').attr('href');
    if (!activeTabHref) return;
    let activeTabId = activeTabHref.replace('#tab-map-', '');

    // 1. FILTERING
    let filteredData = window.panelDataOriginal[activeTabId].filter(item => {
        let matchName = item.name.includes(keyword);
        let matchKondisi = true;
        if (kondisiFilter !== 'ALL') {
            matchKondisi = (item.kondisi || "").includes(kondisiFilter);
        }
        return matchName && matchKondisi;
    });

    // 2. SORTING (Logika Urutan: BAIK -> RR -> RB)
    filteredData.sort((a, b) => {
        let kA = (a.kondisi || "").toUpperCase();
        let kB = (b.kondisi || "").toUpperCase();

        let getSkor = (k) => {
            if (k.includes('RB') || k.includes('BERAT')) return 3;
            if (k.includes('RR') || k.includes('RINGAN')) return 2;
            if (k.includes('BAP')) return 4;
            return 1; // BAIK
        };

        let skorA = getSkor(kA);
        let skorB = getSkor(kB);

        if (sortBy === 'RB_FIRST') return skorB - skorA; // RB(3) ke BAIK(1)
        if (sortBy === 'BAIK_FIRST') return skorA - skorB; // BAIK(1) ke RB(3)
        if (sortBy === 'NAMA_ASC') return a.name.localeCompare(b.name);
        return 0;
    });

    // 3. RENDER
    window.panelDataFiltered[activeTabId] = filteredData;
    window.panelPage[activeTabId] = 1;
    window.renderPanelList(activeTabId);
}

// Tambahkan listener untuk mendeteksi perubahan dropdown & ketikan
$(document).on('keyup', '#map-search-input', updatePanelFilter);
$(document).on('change', '#map-filter-kondisi, #map-sort-data', updatePanelFilter);

// PERBAIKAN PADA EVENT KLIK TAB (Agar filter tetap teraplikasi saat pindah tab)
$(document).on('click', '.panel-tab-btn', function(e) {
    e.preventDefault();
    $('.panel-tab-btn').removeClass('active');
    $(this).addClass('active');
    
    $('.panel-tab-content').hide();
    const targetId = $(this).attr('href');
    $(targetId).show();

    // Langsung panggil fungsi filter agar tab baru mengikuti dropdown yang ada
    updatePanelFilter(); 
});

    $(document).on('shown.bs.tab', '.custom-map-panel a[data-bs-toggle="pill"]', function (e) {
        const targetKategori = $(e.target).attr('href').replace('#tab-map-', '');
        $('#map-search-input').val('');
        window.panelDataFiltered[targetKategori] = [...window.panelDataOriginal[targetKategori]];
        window.panelPage[targetKategori] = 1;
        window.renderPanelList(targetKategori);
    });

    fetch('/api/bangunan/all/')
        .then(res => res.json())
        .then(response => {
        let daftarAset = [];
        if (Array.isArray(response)) daftarAset = response;
        else if (response.data) daftarAset = response.data;

        window.panelDataOriginal.bangunan = []; 
    
            daftarAset.forEach(b => {
                if (b.latitude && b.longitude) {
                    let rawLat = parseFloat(b.latitude);
                    let rawLng = parseFloat(b.longitude);
                    let fixLat = (Math.abs(rawLat) > 90) ? rawLng : rawLat;
                    let fixLng = (Math.abs(rawLat) > 90) ? rawLat : rawLng;

                    if (fixLat !== 0 && !isNaN(fixLat)) {
                        
                        const iconUrl = `/static/icons/${b.kode_aset || 'default'}.png`; 
                        const epaksiIcon = L.icon({
                            iconUrl: iconUrl,
                            iconSize: [32, 32],     
                            iconAnchor: [16, 16],    
                            popupAnchor: [0, -16],   
                        });

                        const marker = L.marker([fixLat, fixLng], {
                            icon: epaksiIcon,
                            riseOnHover: true,
                            pane: 'paneBangunan',
                            dataTargetCari: (b.nama_poligon || b.di || "").trim().toUpperCase()
                        });

                            marker.on('click', function(e) {
                                const targetCariRaw = b.nama_poligon || b.di || ""; 
                                const targetArray = targetCariRaw.split(',').map(item => item.trim().toUpperCase());
                                
                                console.log("Memulai pencarian poligon untuk array:", targetArray);

                                if (targetArray.length > 0 && targetArray[0] !== "") {
                                    let found = false;

                                    grupKategori['lahan'].eachLayer(function(geoJsonLayer) {
                                        geoJsonLayer.eachLayer(function(polygonLayer) {
                                            const namaAsli = polygonLayer.options.kunciPencarian || "Area Spasial";
                                            const kunciPoligon = namaAsli.trim().toUpperCase();

                                            // Cek apakah kunciPoligon ada di dalam array target
                                            if (targetArray.includes(kunciPoligon)) {
                                                found = true;
                                                console.log("Cocok! Menyalakan poligon:", kunciPoligon);

                                                $(".polygon-blink").removeClass("polygon-blink");
                                                const domPath = polygonLayer.getElement();
                                                if (domPath) {
                                                    polygonLayer.bringToFront();
                                                    domPath.classList.add('polygon-blink');
                                                    setTimeout(() => domPath.classList.remove('polygon-blink'), 3500);
                                                }

                                                const props = polygonLayer.feature.properties;
                                                const luasBaku = props.luas_fungsional || props.Luas_Fung || props.LUAS || "0";

                                                // Isi daftar poligon yang ditemukan ke dalam popup
                                                const targetDiv = document.getElementById(`info-area-${b.id}`);
                                                if (targetDiv) {
                                                    // Jika sudah ada isinya (karena nemu >1 poligon), tambahkan
                                                    let currentHTML = targetDiv.innerHTML;
                                                    targetDiv.innerHTML = currentHTML + `
                                                        <div style="margin-top:8px; padding:6px; background:#e8f4f8; border-left:4px solid #0d3b66; font-size:11px;">
                                                            <b>Area Fungsional Terhubung:</b><br>
                                                            <i class="fa-solid fa-draw-polygon"></i> ${namaAsli} (${luasBaku} Ha)
                                                        </div>
                                                    `;
                                                }
                                            }
                                        });
                                    });

                                    // Blink marker
                                    window.activeBlinkMarker = marker;
                                    if (window.activeBlinkMarker._icon) {
                                        window.activeBlinkMarker._icon.classList.add('marker-blink');
                                    }

                                    setTimeout(() => { marker.openPopup(); }, 200); 

                                    if (!found) {
                                        console.warn("Peringatan: Tidak satupun poligon ditemukan untuk target:", targetArray);
                                    }
                                } else {
                                    marker.openPopup(); // Tetap buka popup kalau tidak punya poligon
                                }
                            });

                        let warnaKondisi = b.kondisi === 'BAIK' ? '#28a745' : (b.kondisi === 'RR' ? '#ffc107' : '#dc3545');

                        const popupContent = `
                            <div style="min-width:200px; font-family: sans-serif;">
                                <div style="background:${warnaKondisi}; color:white; padding:8px; border-radius:4px 4px 0 0; font-weight:bold; text-align:center;">
                                    ${b.nomenklatur || 'Aset Bangunan'}
                                </div>
                                <div style="padding:10px; border:1px solid #ddd; border-top:none; background:white;">
                                    <table style="width:100%; font-size:12px; border-collapse:collapse; margin-bottom:10px;">
                                        <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>Kode</b></td><td class="text-end">${b.kode_aset_display || b.kode_aset || '-'}</td></tr>
                                        <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>Kondisi</b></td><td class="text-end"><b>${b.kondisi || '-'}</b></td></tr>
                                        <tr style="border-bottom:1px solid #eee;"><td style="padding:4px 0;"><b>D.I.</b></td><td class="text-end">${b.di || '-'}</td></tr>
                                        
                                        <tr style="border-bottom:1px solid #eee;">
                                            <td style="padding:4px 0; color:#0d3b66;"><b>Luas Layanan</b></td>
                                            <td class="text-end"><b>${b.luas_areal || '0'} Ha</b></td>
                                        </tr>
                                        <tr style="border-bottom:1px solid #eee;">
                                            <td style="padding:4px 0;"><b>Area (Spasial)</b></td>
                                            <td class="text-end"><span id="area-spasial-${b.id}">${b.nama_poligon || '-'}</span></td>
                                        </tr>

                                        <tr><td style="padding:4px 0;"><b>Surveyor</b></td><td class="text-end">${b.surveyor || '-'}</td></tr>

                                        <div class="alert alert-warning p-1 mt-2 mb-0" style="font-size: 0.75rem;">
                                            <i class="fas fa-info-circle"></i> <b>Catatan:</b><br>
                                            ${b.keterangan || '-'}
                                        </div>
                                    </table>
                                    
                                    ${b.foto_aset ? 
                                        `<img src="${b.foto_aset}" style="width:100%; height:120px; object-fit:cover; border-radius:4px;">` : 
                                        `<div style="text-align:center; color:#999; font-size:11px; padding:10px; border:1px dashed #ccc;">Foto belum tersedia</div>`
                                    }

                                    <div id="info-area-${b.id}"></div>

                                    <button onclick="showDetailPaiIksi(${b.id})" class="btn btn-sm w-100" 
                                            style="background:#0d3b66; color:white; margin-top:10px; border:none; padding:8px; cursor:pointer; font-weight:bold;">
                                        <i class="fa-solid fa-eye"></i> LIHAT DETAIL
                                    </button>
                                </div>
                            </div>
                        `;
                        
                        // Penting: Reset info-area setiap kali popup tertutup agar tidak numpuk
                        marker.on('popupclose', function() {
                            const targetDiv = document.getElementById(`info-area-${b.id}`);
                            if(targetDiv) targetDiv.innerHTML = '';
                        });

                        marker.bindPopup(popupContent);
                        marker.addTo(layerBangunanGroup);

                                                // --- LOGIKA WARNA KONDISI UNTUK LIST PANEL (MAP KESELURUHAN) ---
                        let labelKondisi = (b.kondisi || 'BAIK').toUpperCase();
                        let badgeColorClass = 'bg-success'; // Default Hijau
                        let borderKondisi = '#28a745'; // Default Hijau

                        if (labelKondisi.includes('RR') || labelKondisi.includes('RINGAN') || labelKondisi.includes('SEDANG')) {
                            badgeColorClass = 'bg-warning text-dark'; borderKondisi = '#ffc107'; // Kuning
                        } else if (labelKondisi.includes('RB') || labelKondisi.includes('BERAT')) {
                            badgeColorClass = 'bg-danger'; borderKondisi = '#dc3545'; // Merah
                        } else if (labelKondisi.includes('BAP') || labelKondisi.includes('PASANGAN')) {
                            badgeColorClass = 'bg-secondary'; borderKondisi = '#6c757d'; // Abu-abu
                        }

                        let itemHtml = `
                            <div class="list-group-item item-bangunan" data-lat="${fixLat}" data-lng="${fixLng}" 
                                 style="cursor:pointer; border-left: 4px solid ${borderKondisi}; margin-bottom: 2px; border-radius: 4px;">
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px;">
                                    <b style="font-size: 11px; color: #333; max-width: 70%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                        ${b.nomenklatur || b.kode_aset || 'Aset Bangunan'}
                                    </b>
                                    <span class="badge ${badgeColorClass}" style="font-size: 8px; min-width: 45px;">${labelKondisi}</span>
                                </div>
                                <div style="font-size: 9px; color: #666;"><i class="fa-solid fa-map-pin" style="color: #dc3545;"></i> ${b.di || '-'}</div>
                            </div>`;

                        window.panelDataOriginal.bangunan.push({ 
                            name: (b.nomenklatur || b.kode_aset || b.nama_poligon || "aset").toLowerCase(), 
                            kondisi: labelKondisi, 
                            html: itemHtml 
                        });
                    }
                }
            });

            window.panelDataFiltered.bangunan = [...window.panelDataOriginal.bangunan];
            window.renderPanelList('bangunan');
        })
        .catch(err => console.error("❌ Error mengambil data bangunan:", err));

    fetch('/api/layer-pendukung/')
        .then(res => res.json())
        .then(layers => {
            if (grupKategori['lahan']) grupKategori['lahan'].clearLayers();
            if (grupKategori['jalan']) grupKategori['jalan'].clearLayers();
            if (grupKategori['wilayah']) grupKategori['wilayah'].clearLayers();
            if (grupKategori['air']) grupKategori['air'].clearLayers();
            layers.forEach(layer => {
                if (layer.file_geojson && layer.file_geojson.toLowerCase().endsWith('.json')) {
                    fetch(layer.file_geojson + "?v=" + new Date().getTime())
                        .then(r => r.json())
                        .then(geojsonData => {
                            let targetPane = 'panePendukung';
                            if (layer.kategori === 'wilayah') targetPane = 'paneWilayah';
                            if (layer.kategori === 'lahan') targetPane = 'paneLahan';
                            const gLayer = L.geoJSON(geojsonData, {
                                pane: targetPane,
                                style: {
                                    color: layer.warna_garis || '#3388ff',
                                    weight: layer.kategori === 'jalan' ? 3 : 2,
                                    fillOpacity: (layer.kategori === 'wilayah' || layer.kategori === 'lahan') ? 0.3 : 0,
                                    dashArray: layer.kategori === 'wilayah' ? '5, 5' : '0'
                                },
                                onEachFeature: (f, l) => {
                                    let namaPasti = layer.nama;
                                    if (layer.nama === "Luasan Areal Fungsional") {
                                        namaPasti = f.properties.nama_di || f.properties.Nama_DI || f.properties.nama || "Area Spasial";
                                    }
                                    l.bindTooltip(namaPasti, { sticky: true });
                                    l.options.kunciPencarian = namaPasti;

                                    if (layer.kategori === 'lahan') {
                                        l.on('click', function(e) {
                                            const kunciPoligon = namaPasti.trim().toUpperCase();
                                            let markerKetemu = false;

                                            L.DomEvent.stopPropagation(e);

                                            if (typeof matikanSemuaKedipan === "function") {
                                                matikanSemuaKedipan();
                                            }

                                            window.activeBlinkPolygon = e.target;
                                            const domPath = e.target.getElement(); 
                                            if (domPath) {
                                                domPath.classList.add('polygon-blink');
                                                e.target.bringToFront(); 
                                            }

                                            // BUKA POPUP BANGUNAN JIKA KLIK POLIGON
                                            layerBangunanGroup.eachLayer(function(marker) {
                                                const rawTarget = marker.options.dataTargetCari || "";
                                                const arrayTargets = rawTarget.split(',').map(i => i.trim().toUpperCase());

                                                if (arrayTargets.includes(kunciPoligon)) {
                                                    markerKetemu = true;
                                                    
                                                    window.activeBlinkMarker = marker;
                                                    if (window.activeBlinkMarker._icon) {
                                                        window.activeBlinkMarker._icon.classList.add('marker-blink');
                                                    }

                                                    setTimeout(() => {
                                                        marker.openPopup();
                                                    }, 200); 
                                                }
                                            });

                                            if (!markerKetemu) {
                                                console.log("Pencarian:", kunciPoligon, "- Belum ada data aset bangunan yang terhubung.");
                                            }
                                        });
                                    }
                                }
                            });

                            if (grupKategori[layer.kategori]) {
                                gLayer.addTo(grupKategori[layer.kategori]);
                            }
                        });
                }
            });
        });

    fetch('/api/daerah-irigasi/') 
        .then(res => res.json())
        .then(response => {
            const daftarDI = response.filter(di => di.is_approved === true); 
            window.panelDataOriginal.primer = [];
            window.panelDataOriginal.sekunder = [];
            window.panelDataOriginal.tersier = [];

            const filterSelect = $('#filter-di');
            filterSelect.empty().append('<option value="">-- Pilih Daerah Irigasi --</option>');
            
            daftarDI.forEach(di => {
                filterSelect.append(`<option value="${di.id}">${di.nama_di}</option>`);
                diDataMap[di.id] = di;

                const diGroup = L.featureGroup().addTo(mapKeseluruhan);
                diLayers[di.id] = diGroup;

                if (di.saluran_list && di.saluran_list.length > 0) {
                    di.saluran_list.forEach(saluran => {
                        if (saluran.is_approved != true) return;
                        const geometri = saluran.geometry_data || saluran.geom;

                        if (geometri && geometri.type && geometri.coordinates) {
                            
                            const s_baik = parseFloat(saluran.panjang_baik) || 0;
                            const s_rr   = parseFloat(saluran.panjang_rr) || 0;
                            const s_rb   = parseFloat(saluran.panjang_rb) || 0;
                            const s_bap  = parseFloat(saluran.panjang_bap) || 0;
                            const totalPanjang = parseFloat(saluran.panjang_saluran) || 0;

                            const totalKondisi = s_baik + s_rr + s_rb + s_bap;
                            const pembagi = totalKondisi > 0 ? totalKondisi : (totalPanjang > 0 ? totalPanjang : 1);

                            const pctBaik = (s_baik / pembagi) * 100;
                            const pctRR   = (s_rr / pembagi) * 100;
                            const pctRB   = (s_rb / pembagi) * 100;
                            const pctBAP  = (s_bap / pembagi) * 100;

                            const popupContent = `
                                <div style="min-width: 260px; font-family: sans-serif;">
                                    <div style="background: #0d3b66; color: white; padding: 8px; border-radius: 4px 4px 0 0; font-weight: bold; font-size: 13px; text-align: center;">
                                        DETAIL SALURAN
                                    </div>
                                    <div style="padding: 10px; border: 1px solid #ccc; border-top: none; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                                        <table style="width: 100%; font-size: 11px; border-collapse: collapse; margin-bottom: 8px;">
                                            <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0; width: 35%;"><b>Nama</b></td><td>: <b>${saluran.nama_saluran || '-'}</b></td></tr>
                                            <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>DI</b></td><td>: ${di.nama_di || '-'}</td></tr>
                                            <tr style="border-bottom: 1px solid #eee;"><td style="padding: 4px 0;"><b>Tingkat</b></td><td>: ${saluran.tingkat_jaringan || '-'}</td></tr>
                                            <tr><td style="padding: 4px 0;"><b>P. Total</b></td><td>: ${totalPanjang.toLocaleString('id-ID')} m</td></tr>
                                        </table>
                                        
                                        <div style="background: #f8f9fc; border: 1px solid #e3e6f0; border-radius: 4px; padding: 8px; margin-bottom: 10px;">
                                            <div style="font-size: 10px; font-weight: bold; margin-bottom: 6px; color: #5a5c69;">KONDISI FISIK (Meter)</div>
                                            
                                            <div class="progress" style="height: 10px; border-radius: 5px; margin-bottom: 8px; background-color: #e9ecef; overflow: hidden; display: flex;">
                                                <div style="width: ${pctBaik}%; background-color: #1cc88a;" title="Baik: ${s_baik.toLocaleString('id-ID')}m"></div>
                                                <div style="width: ${pctRR}%; background-color: #f6c23e;" title="Rusak Ringan: ${s_rr.toLocaleString('id-ID')}m"></div>
                                                <div style="width: ${pctRB}%; background-color: #e74a3b;" title="Rusak Berat: ${s_rb.toLocaleString('id-ID')}m"></div>
                                                <div style="width: ${pctBAP}%; background-color: #858796;" title="BAP: ${s_bap.toLocaleString('id-ID')}m"></div>
                                            </div>
                                            
                                            <table style="width: 100%; font-size: 10px; text-align: center; line-height: 1.2;">
                                                <tr>
                                                    <td style="width: 25%;"><span style="color: #1cc88a; font-weight: 800;">BAIK</span><br>${s_baik.toLocaleString('id-ID')}</td>
                                                    <td style="width: 25%; border-left: 1px solid #ddd;"><span style="color: #f6c23e; font-weight: 800;">RR</span><br>${s_rr.toLocaleString('id-ID')}</td>
                                                    <td style="width: 25%; border-left: 1px solid #ddd;"><span style="color: #e74a3b; font-weight: 800;">RB</span><br>${s_rb.toLocaleString('id-ID')}</td>
                                                    <td style="width: 25%; border-left: 1px solid #ddd;"><span style="color: #858796; font-weight: 800;">BAP</span><br>${s_bap.toLocaleString('id-ID')}</td>
                                                </tr>
                                            </table>
                                        </div>
                                        <button onclick="ambilDataDanBukaModal(${saluran.id}, ${di.id})" style="width: 100%; background: #007bff; color: white; border: none; padding: 6px; border-radius: 3px; cursor: pointer; font-size: 10px; font-weight: bold; letter-spacing: 0.5px;">
                                            <i class="fa-solid fa-eye"></i> LIHAT DETAIL SALURAN
                                        </button>
                                    </div>
                                </div>`;

                            L.geoJSON(geometri, {
                                pane: 'paneSaluran',
                                style: { color: "#2d93ad", weight: 4, opacity: 0.8 },
                                onEachFeature: function(feature, layer) {
                                    layer.options.is_approved = saluran.is_approved;
                                    feature.properties = saluran;
                                    window.dictLayerSaluran[saluran.id] = layer; 
                                    
                                    layer.bindPopup(popupContent);

                                    layer.on('click', function(e) {
                                        const targetLayer = e.target;
                                        
                                        window.currentActiveSaluranId = saluran.id;
                                        
                                        Object.values(window.dictLayerSaluran).forEach(l => {
                                            if (l.setStyle) l.setStyle({ color: "#2d93ad", weight: 4 });
                                        });

                                        if (targetLayer.setStyle) {
                                            targetLayer.setStyle({ color: "#1cc88a", weight: 4 });
                                        }
                                        
                                        if (window.currentActiveSegments) {
                                            mapKeseluruhan.removeLayer(window.currentActiveSegments);
                                        }
                                        window.currentActiveSegments = L.featureGroup().addTo(diGroup);

                                        if (saluran.segmen_list && saluran.segmen_list.length > 0) {
                                            saluran.segmen_list.forEach(segmen => {
                                                if (segmen.geometry_data && segmen.kondisi !== 'BAIK') {
                                                    let warnaSegmen = "#2d93ad";
                                                    if (segmen.kondisi === 'RR') warnaSegmen = "#f6c23e"; 
                                                    if (segmen.kondisi === 'RB') warnaSegmen = "#e74a3b"; 
                                                    if (segmen.kondisi === 'BAP') warnaSegmen = "#858796"; 

                                                    L.geoJSON(segmen.geometry_data, {
                                                        pane: 'paneSaluran',
                                                        style: { color: warnaSegmen, weight: 6, opacity: 1 },
                                                        onEachFeature: function(f, l) {
                                                            l.bindPopup(popupContent);
                                                        }
                                                    }).addTo(window.currentActiveSegments);
                                                }
                                            });
                                        }

                                        targetLayer.openPopup();
                                    });

                                   layer.on('mouseover', function() {
                                        this.setStyle({ color: "#ffc107", weight: 7 }); 
                                    });
                                    layer.on('mouseout', function() {
                                        if (window.currentActiveSaluranId === saluran.id) {
                                            this.setStyle({ color: "#1cc88a", weight: 4 });
                                        } else {
                                            this.setStyle({ color: "#2d93ad", weight: 4 });
                                        }
                                    });
                                }
                            }).addTo(diGroup);

                            let itemHtml = `
                                <div class="list-group-item item-saluran" data-sal-id="${saluran.id}" style="cursor:pointer;">
                                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px;">
                                        <b style="font-size: 11px; color: #333; max-width: 75%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                            ${saluran.nama_saluran || '-'}
                                        </b>
                                        <span class="badge bg-info text-dark" style="font-size: 10px;">${parseFloat(saluran.panjang_saluran||0).toFixed(0)}m</span>
                                    </div>
                                    <div style="font-size: 9px; color: #666;"><i class="fa-solid fa-water" style="color: #0d3b66;"></i> D.I. ${di.nama_di || '-'}</div>
                                </div>`;

                            let tingkat = (saluran.tingkat_jaringan || "").toLowerCase().trim();
                            let kodeSal = (saluran.kode_aset_saluran || "").toUpperCase().trim();
                            let namaSal = (saluran.nama_saluran || "").toLowerCase().trim();

                            let itemObj = { 
                                name: namaSal, 
                                kondisi: (saluran.kondisi_aset || 'BAIK').toUpperCase(), // <--- TITIPKAN DATA KONDISI DI SINI
                                html: itemHtml 
                            };

                            if (tingkat.includes('primer') || kodeSal === 'S01' || namaSal.includes('induk')) {
                                window.panelDataOriginal.primer.push(itemObj);
                            } else if (tingkat.includes('sekunder') || kodeSal === 'S02') {
                                window.panelDataOriginal.sekunder.push(itemObj);
                            } else {
                                window.panelDataOriginal.tersier.push(itemObj);
                            }
                        }

                        
                    });
            
                }
            });
            
            if (typeof aktifkanLogikaFilter === "function") {
                aktifkanLogikaFilter();
            }

            window.panelDataFiltered.primer = [...window.panelDataOriginal.primer];
            window.panelDataFiltered.sekunder = [...window.panelDataOriginal.sekunder];
            window.panelDataFiltered.tersier = [...window.panelDataOriginal.tersier];
            
            window.renderPanelList('primer');
            window.renderPanelList('sekunder');
            window.renderPanelList('tersier');
        })
        .catch(err => console.error("❌ Error Fetch Data:", err));

    ['primer', 'sekunder', 'tersier', 'bangunan'].forEach(kat => {
        window.panelDataFiltered[kat] = [...window.panelDataOriginal[kat]];
        window.renderPanelList(kat);
    });
}


    $(document).on('click', '.item-saluran', function() {
        const salId = $(this).data('sal-id');
        const layerObj = window.dictLayerSaluran[salId];

        // 1. Reset/Bersihkan dulu semua garis saluran ke warna biru standar
        Object.values(window.dictLayerSaluran).forEach(layer => {
            if (layer.setStyle) layer.setStyle({ color: "#1cc88a", weight: 4 });
        });

        if (layerObj) {
            // 2. Beri efek tebal & warna kuning untuk saluran yang baru diklik
            if (layerObj.setStyle) layerObj.setStyle({ color: "#ffc107", weight: 8 });

            // 3. Terbang mem-paskan kamera ke garis tersebut
            if (layerObj.getBounds) {
                mapKeseluruhan.flyToBounds(layerObj.getBounds(), { padding: [50, 50], maxZoom: 17, duration: 1.5 });
            }
            // Buka popup
            layerObj.openPopup();
        }
    });

    // Klik Bangunan
    $(document).on('click', '.item-bangunan', function() {
        const lat = parseFloat($(this).data('lat'));
        const lng = parseFloat($(this).data('lng'));
        mapKeseluruhan.flyTo([lat, lng], 18, { animate: true, duration: 1.5 });
    });


    // Bersihkan filter ketika ganti tab
    // Bersihkan filter dan atur tampilan murni pakai jQuery (Tanpa Bootstrap JS)
    $(document).on('click', '.panel-tab-btn', function(e) {
        e.preventDefault();
        
        // 1. Reset warna tombol
        $('.panel-tab-btn').removeClass('active');
        $(this).addClass('active');
        
        // 2. Sembunyikan semua isi tab secara paksa
        $('.panel-tab-content').hide();
        
        // 3. Tampilkan isi tab yang dituju
        const targetId = $(this).attr('href');
        $(targetId).show();

        // 4. Reset Pencarian & Data
        const targetKategori = targetId.replace('#tab-map-', '');
        $('#map-search-input').val('');
        window.panelDataFiltered[targetKategori] = [...window.panelDataOriginal[targetKategori]];
        window.panelPage[targetKategori] = 1;
        window.renderPanelList(targetKategori);
    });

document.addEventListener('fullscreenchange', () => {
    setTimeout(() => {
        mapKeseluruhan.invalidateSize();
    }, 300);
});

function aktifkanLogikaFilter() {
    $('#filter-di').off('change').on('change', function() {
        const id = $(this).val();

        // --- 1. RESET SEMUA EFEK SEBELUMNYA ---
        Object.values(diLayers).forEach(layerGroup => {
            layerGroup.eachLayer(function(l) {
                function resetMendalam(layer) {
                    if (layer.eachLayer) {
                        layer.eachLayer(resetMendalam);
                    } else if (layer instanceof L.Path) {
                        layer.setStyle({ color: "#1cc88a", weight: 3, opacity: 0.7 }); // <--- UBAH DI SINI
                        if (layer._path) { $(layer._path).addClass('no-blink').removeClass('active-filter'); }
                    }
                }
                resetMendalam(l);
            });
        });


        if (!id || id === "") {
            resetMap();
            $('#peta-info-box').fadeOut(); 
            return;
        }
        
        if (id && diLayers[id]) {
            const selectedLayer = diLayers[id];
            const bounds = selectedLayer.getBounds(); // PINDAHKAN KE SINI
    
            if (bounds && bounds.isValid()) {
                mapKeseluruhan.flyToBounds(bounds, { padding: [50, 50], duration: 1.5 });
            }
            const di = diDataMap[id]; 
            let countData = 0;


            if (di) {
                console.log(`%c 🔎 FILTER TERPILIH: ${di.nama_di} `, 'background: #0d3b66; color: #fff; font-weight: bold;');
                
                $('#info-nama-di').text(di.nama_di || '-');
                $('#info-kewenangan').text(di.kewenangan || 'Kabupaten');
                
                // Set Saluran
                const jmlSaluran = di.saluran_list ? di.saluran_list.length : 0;
                $('#info-saluran').text(jmlSaluran);

                // --- HITUNG JUMLAH BANGUNAN SECARA LIVE DARI API ---
                // Kita panggil API bangunan khusus untuk DI ini
                fetch(`/api/bangunan/${id}/`)
                    .then(res => res.json())
                    .then(resBangunan => {
                        const daftarBangunan = resBangunan.data || [];
                        // Update angka bangunan di Info Box secara real-time
                        $('#info-bangunan').text(daftarBangunan.length);
                        console.log(`📊 Jumlah Bangunan Ditemukan: ${daftarBangunan.length}`);
                    })
                    .catch(err => {
                        console.error("Gagal hitung bangunan:", err);
                        $('#info-bangunan').text('0');
                    });

                if (di.file_skema) {
                    $('#btn-download-skema').attr('href', di.file_skema).show();
                } else {
                    $('#btn-download-skema').hide();
                }

                $('#peta-info-box').fadeIn();
            }

            mapKeseluruhan.closePopup();

            // --- 3. LOGIKA REKURSIF UNTUK HIGHLIGHT ---
            function prosesLayer(target) {
                if (target.eachLayer) {
                    target.eachLayer(function(layer) { prosesLayer(layer); });
                } else if (target instanceof L.Path) {
                    if (target.options && target.options.is_approved === false) return; 
                    countData++;
                    target.setStyle({ color: "#ffc107", weight: 8, opacity: 1 });
                    if (target._path) { $(target._path).removeClass('no-blink').addClass('active-filter'); }
                }
            }

            prosesLayer(selectedLayer);
            console.log(`📊 Saluran Aktif di Peta: ${countData}`);

            // --- 4. TERBANG KE LOKASI ---
            // const bounds = selectedLayer.getBounds();
            // mapKeseluruhan.flyToBounds(bounds, { padding: [50, 50], duration: 1.5 });

        } else {
            console.warn("⚠️ Layer tidak ditemukan.");
            resetMap();
            $('#peta-info-box').fadeOut();
        }
    });
}

function resetMap() {
    if (!mapKeseluruhan) return;
    
    // Matikan pengingat saluran aktif & hapus belang-belang
    window.currentActiveSaluranId = null;
    if (window.currentActiveSegments) {
        mapKeseluruhan.removeLayer(window.currentActiveSegments);
        window.currentActiveSegments = null;
    }
    
    // Kembalikan warna semua saluran ke Biru
    Object.values(diLayers).forEach(layerGroup => {
        layerGroup.eachLayer(function(layer) {
            if (layer instanceof L.Path && layer.setStyle) {
                layer.setStyle({ color: "#2d93ad", weight: 3, opacity: 1 });
            }
        });
    });

    $('#peta-info-box').fadeOut(300);
    $('#filter-di').val(""); 
    mapKeseluruhan.closePopup();
    mapKeseluruhan.flyTo([-6.722, 108.552], 11, { animate: true, duration: 1.2 });
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
        hideAllDetails();
    }
});

// Ganti fungsi showDetailPaiIksi di dashboard.js dengan ini:
function showDetailPaiIksi(asetId, namaAset) {
    // Tampilkan loading jika perlu
    console.log("Mengambil detail untuk aset ID:", asetId);

    // Panggil API untuk mendapatkan data detail terbaru dari server
    fetch(`/api/bangunan/${asetId}/`)
        .then(res => res.json())
        .then(data => {
            // PANGGIL fungsi yang ada di detailAsetBangunan.js
            if (typeof bukaModalDetailAset === "function") {
                bukaModalDetailAset(data);
            } else {
                console.error("Fungsi bukaModalDetailAset tidak ditemukan!");
            }
        })
        .catch(err => {
            console.error("Gagal mengambil data detail:", err);
            alert("Gagal memuat detail aset.");
        });
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

function showDrillDownTotalDI() {
    gsap.to(".container-fluid", { duration: 0.2, opacity: 0, onComplete: () => {
        hideAllDetails();
        $("#view-detail-di").show().css("opacity", 1);
        gsap.to(".container-fluid", { duration: 0.3, opacity: 1 });
    }});
}

function backToSebaran() {
    gsap.to("#view-drilldown", { 
        duration: 0.2, 
        opacity: 0, 
        onComplete: () => {
            $("#view-drilldown").hide();
            
            // Tampilkan kembali view sebaran (3 kolom)
            $("#view-detail-sebaran").show();
            gsap.to("#view-detail-sebaran", { duration: 0.3, opacity: 1 });
            
            // Re-render grafik di sebaran agar tidak freeze
            renderRankingSebaran(); 
            initKomposisiCharts(); // Untuk doughnut global di kolom 1
        }
    });
}

// Tambahkan listener saat slide berpindah agar chart menggambar ulang jika perlu
var myCarousel = document.getElementById('carouselLuas')
myCarousel.addEventListener('slid.bs.carousel', function () {
    // Memaksa chart untuk menyesuaikan ukuran dengan container slider yang baru tampil
    if(window.myChartBar) window.myChartBar.resize();
    if(window.myChartPie) window.myChartPie.resize();
    if(window.myChartInteraktif) window.myChartInteraktif.resize();
})


// Logika untuk Chart 1 (Handling many data)
function updateBarChart(data) {
    const ctx = document.getElementById('chartDetailLuasBar').getContext('2d');
    const chartWidth = data.labels.length > 10 ? data.labels.length * 80 : 800;
    document.getElementById('chartDetailLuasBar').parentElement.style.width = chartWidth + 'px';
    
    // Inisialisasi Chart.js seperti biasa...
}

// Logika untuk Chart 2 (Perbandingan)
// --- LOGIKA PERBANDINGAN PRIORITAS D.I. ---
$('#selectDI1, #selectDI2').on('change', function() {
    const id1 = $('#selectDI1').val();
    const id2 = $('#selectDI2').val();
    
    // Pastikan kedua dropdown sudah dipilih
    if(id1 && id2) {
        
        // 1. Ambil data dari variabel global window.dataIrigasiFull
        // Gunakan == (bukan ===) karena value dari dropdown berbentuk text (string), sedangkan id mungkin integer
        const data1 = window.dataIrigasiFull.find(di => di.id == id1);
        const data2 = window.dataIrigasiFull.find(di => di.id == id2);
        
        if (data1 && data2) {
            
            // 2. Hitung Persentase Fungsional (Realisasi)
            let pctFungsional1 = data1.luas_baku_permen > 0 ? (data1.luas_fungsional / data1.luas_baku_permen) * 100 : 0;
            let pctFungsional2 = data2.luas_baku_permen > 0 ? (data2.luas_fungsional / data2.luas_baku_permen) * 100 : 0;

            // 3. Hitung Gap Kehilangan (Luas yang tidak terairi)
            let gap1 = 100 - pctFungsional1;
            let gap2 = 100 - pctFungsional2;

            // 4. Logika Penentuan Prioritas (Yang persentase kehilangannya lebih besar = Prioritas)
            let prioritasNama = "";
            let prioritasGap = 0;

            if (gap1 > gap2) {
                prioritasNama = data1.nama_di;
                prioritasGap = gap1;
            } else if (gap2 > gap1) {
                prioritasNama = data2.nama_di;
                prioritasGap = gap2;
            } else {
                prioritasNama = "Keduanya Seimbang";
                prioritasGap = gap1;
            }

            // 5. Tampilkan ke Box Rekomendasi
            $('#namaDIPrioritas').text(prioritasNama);
            $('#valGap').text(prioritasGap.toFixed(2)); // Dibulatkan 2 desimal
            $('#rekomendasiKeputusan').fadeIn(); // Munculkan box merah

            // 6. Gambar Grouped Bar Chart
            const ctx = document.getElementById('chartPerbandinganPrioritas');
            if (ctx) {
                // Hancurkan chart lama jika sudah ada agar tidak error bertumpuk
                if (window.chartPerbandinganPrioritasObj) {
                    window.chartPerbandinganPrioritasObj.destroy();
                }

                window.chartPerbandinganPrioritasObj = new Chart(ctx.getContext('2d'), {
                    type: 'bar',
                    data: {
                        labels: [data1.nama_di, data2.nama_di], // Nama 2 D.I. di sumbu X
                        datasets: [
                            {
                                label: 'Luas Baku (Target)',
                                data: [data1.luas_baku_permen, data2.luas_baku_permen],
                                backgroundColor: '#e74a3b', // Merah
                                borderRadius: 4
                            },
                            {
                                label: 'Luas Fungsional (Realisasi)',
                                data: [data1.luas_fungsional, data2.luas_fungsional],
                                backgroundColor: '#1cc88a', // Hijau
                                borderRadius: 4
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: { position: 'top' },
                            datalabels: {
                                align: 'end',
                                anchor: 'end',
                                color: '#5a5c69',
                                font: { weight: 'bold', size: 11 },
                                formatter: function(value) {
                                    return value + ' Ha'; // Tambahkan teks 'Ha' pada angka
                                }
                            }
                        },
                        scales: {
                            y: { 
                                beginAtZero: true,
                                title: { display: true, text: 'Luas Hektar (Ha)' }
                            }
                        }
                    }
                });
            }
        }
    } else {
        // Jika salah satu dropdown di-reset/kosong, sembunyikan rekomendasi
        $('#rekomendasiKeputusan').fadeOut();
        if (window.chartPerbandinganPrioritasObj) {
            window.chartPerbandinganPrioritasObj.destroy();
        }
    }
});



document.addEventListener('DOMContentLoaded', function() {

    let chartsProporsi = {};

    // 1. Fungsi Pembuat Chart Bulat
    function createProporsiPie(canvasId, labels, data, bgColors, chartName, totalKeseluruhan) {
        const ctx = document.getElementById(canvasId);
        if (!ctx) return;

        if (chartsProporsi[canvasId]) {
            chartsProporsi[canvasId].destroy();
        }

        let totalNilai = data.reduce((a, b) => a + b, 0);
        let finalLabels = totalNilai === 0 ? ['Data Kosong / Belum Diinput'] : labels;
        let finalData = totalNilai === 0 ? [1] : data;
        let finalColors = totalNilai === 0 ? ['#e9ecef'] : bgColors;

        chartsProporsi[canvasId] = new Chart(ctx.getContext('2d'), {
            type: 'pie',
            data: {
                labels: finalLabels,
                datasets: [{
                    data: finalData,
                    backgroundColor: finalColors,
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { 
                        position: 'bottom',
                        labels: { boxWidth: 12, font: { size: 10 } }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                if (totalNilai === 0) return ' Menunggu Data';
                                
                                let val = context.raw;
                                let percentage = totalKeseluruhan > 0 ? ((val / totalKeseluruhan) * 100).toFixed(1) : 0;
                                let labelName = context.label;
                                
                                let valStr = val.toLocaleString('id-ID');
                                let totStr = totalKeseluruhan.toLocaleString('id-ID');

                                // HOVER SESUAI PERMINTAAN
                                if (labelName === "Belum Terairi") {
                                    return ` Belum Terairi : ${valStr} Ha | ${chartName} Keseluruhan : ${totStr} Ha (${percentage}%)`;
                                }
                                return ` ${chartName} ${labelName} : ${valStr} Ha | ${chartName} Keseluruhan : ${totStr} Ha (${percentage}%)`;
                            }
                        }
                    },
                    datalabels: {
                        color: totalNilai === 0 ? '#6c757d' : '#fff',
                        font: { weight: 'bold', size: 11 },
                        formatter: (value, ctx) => {
                            if (totalNilai === 0) return 'Kosong'; 
                            let sum = ctx.chart.data.datasets[0].data.reduce((a, b) => a + b, 0);
                            if (sum === 0 || value === 0) return ''; 
                            return (value * 100 / sum).toFixed(1) + "%";
                        }
                    }
                }
            }
        });
    }

    // 2. Fungsi Mengambil Data dari API dan Merender Chart
    function fetchDanRenderPieCharts() {
        // 🔥 KITA LANGSUNG TEMBAK API DAERAH IRIGASI DI SINI 🔥
        fetch('/api/daerah-irigasi/')
            .then(res => res.json())
            .then(response => {
                // Antisipasi format respons dari DRF (bisa langsung array, bisa di dalam "data")
                let dataIrigasi = Array.isArray(response) ? response : response.data;
                
                if (!dataIrigasi || dataIrigasi.length === 0) return;

                let labelsDI = [];
                let dataBakuPermen = [];
                let dataBakuOnemap = [];
                let dataPotensial = [];
                let dataFungsional = [];
                
                let totalBakuPermen = 0;
                let totalBakuOnemap = 0;
                let totalPotensial = 0;
                let totalFungsional = 0;

                dataIrigasi.forEach(di => {
                    // Gunakan nama asli dari database
                    labelsDI.push(di.nama_di || "");
                    
                    // Tarik data langsung dari response API
                    let bakuPermen = parseFloat(di.luas_baku_permen) || 0;
                    let bakuOnemap = parseFloat(di.luas_baku_onemap) || 0;
                    let potensial = parseFloat(di.luas_potensial) || 0;
                    let fungsional = parseFloat(di.luas_fungsional) || 0;

                    dataBakuPermen.push(bakuPermen);
                    dataBakuOnemap.push(bakuOnemap);
                    dataPotensial.push(potensial);
                    dataFungsional.push(fungsional);

                    totalBakuPermen += bakuPermen;
                    totalBakuOnemap += bakuOnemap;
                    totalPotensial += potensial;
                    totalFungsional += fungsional;
                });

                // Hitung sisa yang tidak terairi. (Kita anggap acuannya Luas Baku)
                let sisaBakuPermen = Math.max(0, totalBakuPermen - totalFungsional);
                let sisaBakuOnemap = Math.max(0, totalBakuOnemap - totalFungsional);

                // --- Susun array KHUSUS UNTUK CHART FUNGSIONAL (Ada Gap) ---
                let labelsFungsional = [...labelsDI, "Belum Terairi"];
                let dataFungsionalPermenChart = [...dataFungsional, sisaBakuPermen];
                let dataFungsionalOnemapChart = [...dataFungsional, sisaBakuOnemap];

                const bgColors = ['#4e73df', '#f6c23e', '#1cc88a', '#e74a3b', '#36b9cc'];
                let bgColorsFungsional = [...bgColors.slice(0, labelsDI.length), '#e9ecef']; 

                // --- RENDER DATA PERMEN PU ---
                // Baku dan Potensial MURNI sesuai porsi DI masing-masing (tanpa sisa abu-abu)
                createProporsiPie('chartDiPermen', labelsDI, dataBakuPermen, bgColors, 'Luas Baku', totalBakuPermen);
                createProporsiPie('chartPaiPermen', labelsDI, dataPotensial, bgColors, 'Luas Potensial', totalPotensial); 
                // Fungsional DITAMBAH sisa yang Belum Terairi
                createProporsiPie('chartIksiPermen', labelsFungsional, dataFungsionalPermenChart, bgColorsFungsional, 'Luas Fungsional', totalBakuPermen);

                // --- RENDER DATA ONEMAP ---
                // Baku dan Potensial MURNI sesuai porsi DI masing-masing (tanpa sisa abu-abu)
                createProporsiPie('chartDiOnemap', labelsDI, dataBakuOnemap, bgColors, 'Luas Baku', totalBakuOnemap);
                createProporsiPie('chartPaiOnemap', labelsDI, dataPotensial, bgColors, 'Luas Potensial', totalPotensial); 
                // Fungsional DITAMBAH sisa yang Belum Terairi
                createProporsiPie('chartIksiOnemap', labelsFungsional, dataFungsionalOnemapChart, bgColorsFungsional, 'Luas Fungsional', totalBakuOnemap);
            })
            .catch(err => console.error("Gagal menarik data dari API:", err));
    }

    // 3. Eksekusi fungsi fetch saat halaman dimuat
    fetchDanRenderPieCharts();

    // 4. Logika Tombol Switcher Permen/OneMap
    $('#btn-switch-luas').off('click').on('click', function() {
        let mode = $(this).attr('data-mode');
        let title = $('#title-statistik');

        if (mode === 'permen') {
            $('#container-permen').hide();
            $('#container-onemap').fadeIn();
            $(this).attr('data-mode', 'onemap');
            $(this).html('<i class="fas fa-exchange-alt me-2 text-primary"></i> Ganti ke Data Permen PU');
            title.text('DATA ONEMAP GEOSPASIAL').removeClass('text-primary').addClass('text-success');
        } else {
            $('#container-onemap').hide();
            $('#container-permen').fadeIn();
            $(this).attr('data-mode', 'permen');
            $(this).html('<i class="fas fa-exchange-alt me-2 text-warning"></i> Ganti ke Data OneMap');
            title.text('DATA PERMEN PU 14/2015').removeClass('text-success').addClass('text-primary');
        }
    });

});


document.addEventListener('DOMContentLoaded', function() {
    
    fetch('/api/daerah-irigasi/')
        .then(response => response.json())
        .then(res => {
            renderChartsOnly(res);
        })
        .catch(err => console.error("Gagal update Chart:", err));

    function renderChartsOnly(allData) {
        let labelsDI = [];
        
        // Siapkan penampung untuk Chart Kanan (Per DI)
        let dsPrimer = { baik: [], rr: [], rb: [], bap: [], totals: [] };
        let dsSekunder = { baik: [], rr: [], rb: [], bap: [], totals: [] };
        let dsTersier = { baik: [], rr: [], rb: [], bap: [], totals: [] };
        
        // Siapkan penampung untuk Chart Kiri (Global Keseluruhan)
        let pTotal = [0, 0, 0, 0], sTotal = [0, 0, 0, 0], tTotal = [0, 0, 0, 0];

        allData.forEach(di => {
            labelsDI.push(di.nama_di);

            let primer = { baik: 0, rr: 0, rb: 0, bap: 0 };
            let sekunder = { baik: 0, rr: 0, rb: 0, bap: 0 };
            let tersier = { baik: 0, rr: 0, rb: 0, bap: 0 };

            // Mengelompokkan panjang berdasarkan jenis saluran per DI
            if (di.saluran_list && Array.isArray(di.saluran_list)) {
                di.saluran_list.forEach(sal => {
                    let kode = sal.kode_aset_saluran;
                    let pBaik = parseFloat(sal.panjang_baik) || 0;
                    let pRr = parseFloat(sal.panjang_rr) || 0;
                    let pRb = parseFloat(sal.panjang_rb) || 0;
                    let pBap = parseFloat(sal.panjang_bap) || 0;

                    if (kode === 'S01') { 
                        primer.baik += pBaik; primer.rr += pRr; primer.rb += pRb; primer.bap += pBap;
                    } else if (kode === 'S02') { 
                        sekunder.baik += pBaik; sekunder.rr += pRr; sekunder.rb += pRb; sekunder.bap += pBap;
                    } else if (kode === 'S15') { 
                        tersier.baik += pBaik; tersier.rr += pRr; tersier.rb += pRb; tersier.bap += pBap;
                    }
                });
            }

            // --- HITUNGAN CHART KANAN (PER DI) ---
            let totP = primer.baik + primer.rr + primer.rb + primer.bap;
            let totS = sekunder.baik + sekunder.rr + sekunder.rb + sekunder.bap;
            let totT = tersier.baik + tersier.rr + tersier.rb + tersier.bap;

            dsPrimer.totals.push(totP);
            dsSekunder.totals.push(totS);
            dsTersier.totals.push(totT);

            const getPct = (val, tot) => tot > 0 ? (val / tot * 100) : 0;

            dsPrimer.baik.push(getPct(primer.baik, totP));
            dsPrimer.rr.push(getPct(primer.rr, totP));
            dsPrimer.rb.push(getPct(primer.rb, totP));
            dsPrimer.bap.push(getPct(primer.bap, totP));

            dsSekunder.baik.push(getPct(sekunder.baik, totS));
            dsSekunder.rr.push(getPct(sekunder.rr, totS));
            dsSekunder.rb.push(getPct(sekunder.rb, totS));
            dsSekunder.bap.push(getPct(sekunder.bap, totS));

            dsTersier.baik.push(getPct(tersier.baik, totT));
            dsTersier.rr.push(getPct(tersier.rr, totT));
            dsTersier.rb.push(getPct(tersier.rb, totT));
            dsTersier.bap.push(getPct(tersier.bap, totT));

            // --- HITUNGAN CHART KIRI (GLOBAL METERAN) ---
            pTotal[0] += primer.baik; pTotal[1] += primer.rr; pTotal[2] += primer.rb; pTotal[3] += primer.bap;
            sTotal[0] += sekunder.baik; sTotal[1] += sekunder.rr; sTotal[2] += sekunder.rb; sTotal[3] += sekunder.bap;
            tTotal[0] += tersier.baik; tTotal[1] += tersier.rr; tTotal[2] += tersier.rb; tTotal[3] += tersier.bap;
        });

        // Pastikan chart lama dihapus jika ada
        Chart.helpers.each(Chart.instances, function(instance){
            if (['chartStackedPrimer', 'chartStackedSekunder', 'chartStackedTersier', 'chartKeandalanPrimer', 'chartKeandalanSekunder', 'chartKeandalanTersier'].includes(instance.canvas.id)) {
                instance.destroy();
            }
        });

        // Render Chart Kiri
        createStackedBar('chartStackedPrimer', pTotal);
        createStackedBar('chartStackedSekunder', sTotal);
        createStackedBar('chartStackedTersier', tTotal); 

        // Render Chart Kanan (Carousel 3 Tingkat)
        renderKeandalanChart('chartKeandalanPrimer', labelsDI, dsPrimer);
        renderKeandalanChart('chartKeandalanSekunder', labelsDI, dsSekunder);
        renderKeandalanChart('chartKeandalanTersier', labelsDI, dsTersier);
    }

    function createStackedBar(canvasId, dataArray) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        const total = dataArray.reduce((a, b) => a + b, 0);

        return new Chart(ctx, {
            type: 'bar',
            data: {
                labels: [''], 
                datasets: [
                    { label: 'Baik', data: [dataArray[0]], backgroundColor: '#1cc88a' },
                    { label: 'Rusak Ringan', data: [dataArray[1]], backgroundColor: '#f6c23e' },
                    { label: 'Rusak Berat', data: [dataArray[2]], backgroundColor: '#e74a3b' },
                    { label: 'BAP', data: [dataArray[3]], backgroundColor: '#858796' }
                ]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { stacked: true, max: total > 0 ? total : 100, display: false },
                    y: { stacked: true, display: false }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        enabled: total > 0,
                        callbacks: {
                            label: (ctx) => {
                                let val = ctx.raw;
                                let pct = total > 0 ? ((val / total) * 100).toFixed(1) : 0;
                                // HOVER CHART 1 (METERAN): Baik ( % ) | dari 100 % ( Total Panjang Saluran Primer )
                                return `${ctx.dataset.label} (${pct}%) | dari 100% (${total.toLocaleString('id-ID')} m)`;
                            }
                        }
                    },
                    datalabels: {
                        display: (context) => context.dataset.data[context.dataIndex] > 0,
                        color: '#000', 
                        font: { weight: 'bold', size: 11 },
                        formatter: (value) => Math.round(value).toLocaleString('id-ID') + ' m',
                        anchor: 'center', align: 'center'
                    }
                },
                animation: {
                    onComplete: function(animation) {
                        if (total === 0) {
                            const chart = animation.chart;
                            const { ctx } = chart;
                            ctx.save();
                            ctx.textAlign = 'center';
                            ctx.textBaseline = 'middle';
                            ctx.font = 'bold 12px Arial';
                            ctx.fillStyle = '#858796';
                            ctx.fillText('Data Kosong (0 m)', chart.width / 2, chart.height / 2);
                            ctx.restore();
                        }
                    }
                },
                elements: { bar: { borderRadius: 5, borderSkipped: false } }
            },
            plugins: [ChartDataLabels]
        });
    }

    function renderKeandalanChart(canvasId, labels, ds) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        return new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    { label: 'Baik', data: ds.baik, backgroundColor: '#1cc88a' },
                    { label: 'Rusak Ringan', data: ds.rr, backgroundColor: '#f6c23e' },
                    { label: 'Rusak Berat', data: ds.rb, backgroundColor: '#e74a3b' },
                    { label: 'BAP', data: ds.bap, backgroundColor: '#858796' }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { stacked: true, ticks: { font: { weight: 'bold', color: '#000' } } },
                    y: { 
                        stacked: true, max: 100,
                        title: { display: true, text: 'Persentase (%)', font: { weight: 'bold', color: '#000' } },
                        ticks: { callback: (value) => value + '%' }
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (ctx) => {
                                let pct = ctx.raw.toFixed(1);
                                let totalMeters = ds.totals[ctx.dataIndex]; // Tarik data total meter dari index yang diklik
                                // HOVER CHART 2 (PERSEN): Baik ( % ) | dari 100 % ( Total Panjang Saluran Primer )
                                return `${ctx.dataset.label} (${pct}%) | dari 100% (${totalMeters.toLocaleString('id-ID')} m)`;
                            }
                        }
                    },
                    datalabels: {
                        display: (context) => context.dataset.data[context.dataIndex] > 5, 
                        color: '#000000', 
                        font: { weight: 'bold', size: 10 },
                        formatter: (value) => Math.round(value) + '%',
                        anchor: 'center', align: 'center'
                    }
                }
            },
            plugins: [ChartDataLabels]
        });
    }
});


let currentDIObject = null;

function switchInfoTab(tabName) {
    const allTabs = $(".info-content");
    const targetTab = $(`#content-${tabName}`);

    // Validasi agar tidak muncul error "Target not found" di console
    if (allTabs.length === 0 || targetTab.length === 0) {
        console.warn("GSAP: Element .info-content atau target tab tidak ditemukan.");
        return;
    }

    // Animasi Keluar untuk tab yang sedang aktif
    gsap.to(".info-content:visible", {
        duration: 0.2,
        opacity: 0,
        x: -20,
        display: "none",
        ease: "power2.in",
        onComplete: function() {
            // Animasi Masuk untuk tab target
            gsap.fromTo(targetTab, 
                { opacity: 0, x: 20, display: "none" },
                { 
                    duration: 0.3, 
                    opacity: 1, 
                    x: 0, 
                    display: "block", 
                    ease: "power2.out" 
                }
            );
        }
    });
}

// FUNGSI ZOOM KE OBJEK (SALURAN/BANGUNAN)
function zoomToElement(lat, lng, name) {
    if (mapKeseluruhan) {
        // Efek flyTo agar pergerakan peta elegan
        mapKeseluruhan.flyTo([lat, lng], 17, {
            animate: true,
            duration: 1.5
        });
        
        // Munculkan popup info di lokasi tujuan
        L.popup()
            .setLatLng([lat, lng])
            .setContent(`<div class="p-1"><b>Fokus:</b><br>${name}</div>`)
            .openOn(mapKeseluruhan);
    }
}

function tampilkanInfoDI(data) {
    if (!data) return;

    // 1. Munculkan Box
    $("#peta-info-box").stop().fadeIn();

    // 2. Isi Data Tab Umum
    $("#info-nama-di").text(data.nama_di || "Tidak Diketahui");
    $("#info-luas-f").text(data.luas_fungsional || 0);
    $("#info-panjang").text(data.total_panjang_saluran || 0);

    // 3. Isi List Saluran (Jika ada data di saluran_list)
    let saluranHtml = '';
    if (data.saluran_list && data.saluran_list.length > 0) {
        data.saluran_list.forEach(s => {
            saluranHtml += `
                <div class="list-group-item p-1 d-flex justify-content-between align-items-center">
                    <span>${s.nama_saluran}</span>
                    <span class="badge bg-primary rounded-pill">${s.panjang_saluran}m</span>
                </div>`;
        });
    } else {
        saluranHtml = '<div class="text-center text-muted p-2">Tidak ada data saluran</div>';
    }
    $("#list-saluran-info").html(saluranHtml);

    // 4. Reset ke tab 'umum' dengan animasi GSAP
    switchInfoTab('umum');
}
// 3. Event Listener Close Button
$(document).on('click', '#close-info-btn', function() {
    $("#peta-info-box").fadeOut();
});

$(document).ready(function() {
    // ==========================================
// 1. INIT DATATABLES BANGUNAN MASTER
// ==========================================
if ($('#table-bangunan-master').length) {
    var tableAsetMaster = $('#table-bangunan-master').DataTable({
        "pageLength": 5,
        
        // Dom untuk memunculkan Tombol Export
        "dom": "<'row mb-2'<'col-md-6'l><'col-md-6 text-end'B>>" +
               "<'row'<'col-sm-12'tr>>" +
               "<'row mt-2'<'col-sm-5'i><'col-sm-7'p>>",
               
        // Tombol Monochrome
        "buttons": [
            { extend: 'copy', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-copy"></i> Copy' },
            { extend: 'excel', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-file-excel"></i> Excel' },
            { extend: 'pdf', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-file-pdf"></i> PDF' },
            { extend: 'print', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-print"></i> Print' }
        ],

        "columnDefs": [
            // Matikan sorting manual pada kolom No
            { "searchable": false, "orderable": false, "targets": 0 },
            // Kolom KategoriAsetHidden di Kolom ke-5 (Index 5)
            { "targets": [5], "visible": false, "searchable": true },
            // Matikan fungsi sorting di Kolom Aksi (Index 9)
            { "orderable": false, "targets": [9] } 
        ],
        
        // DEFAULT ORDER: 
        // 1. Kolom 1 (Daerah Irigasi) -> A-Z
        // 2. Kolom 4 (Kode - Nama Bangunan) -> A-Z
        "order": [[1, "asc"], [4, "asc"], [6, "asc"]],

        "language": {
            "search": "Cari Aset:",
            "lengthMenu": "Tampilkan _MENU_ data",
            "info": "Menampilkan _START_ sampai _END_ dari _TOTAL_ aset",
            "infoEmpty": "Tidak ada data tersedia",
            "paginate": {
                "first": "Pertama",
                "last": "Terakhir",
                "next": "Selanjutnya",
                "previous": "Sebelumnya"
            }
        },

        "initComplete": function () {
            var api = this.api();
            // Isi otomatis dropdown D.I. dari kolom index 1
            api.column(3).data().unique().sort().each(function (d, j) {
                if (d && d !== "-") {
                    $('#filter-di-bangunan').append('<option value="' + d + '">' + d + '</option>');
                }
            });
        }
    });

    // Perbarui Nomor Urut otomatis 1,2,3...
    tableAsetMaster.on('order.dt search.dt', function () {
        let i = 1;
        tableAsetMaster.cells(null, 0, { search: 'applied', order: 'applied' }).every(function (cell) {
            this.data(i++);
        });
    }).draw();

    // ------------------------------------------
    // 2. LOGIKA FILTER BANGUNAN
    // ------------------------------------------
    
    // A. Filter Button (Bendung, Pintu, Penunjang)
    $('.btn-filter-aset').on('click', function() {
        $('.btn-filter-aset').removeClass('btn-primary').addClass('btn-outline-primary');
        $(this).removeClass('btn-outline-primary').addClass('btn-primary');
        
        var filterValue = $(this).attr('data-kategori');
        
        if (filterValue) {
            tableAsetMaster.column(5).search('^' + filterValue + '$', true, false).draw();
        } else {
            tableAsetMaster.column(5).search('').draw(); 
        }
    });

    // B. Filter D.I. Dropdown
    $('#filter-di-bangunan').on('change', function () {
        var val = $.fn.dataTable.util.escapeRegex($(this).val());
        // Filter kolom ke-2 (Index 1: Nama D.I.)
        tableAsetMaster.column(3).search(val ? '^' + val + '$' : '', true, false).draw();
    });

    // C. Filter Kondisi Dropdown
    $('#sort-kondisi-bangunan').on('change', function () {
        var val = $.fn.dataTable.util.escapeRegex($(this).val());
        if (val) {
            tableAsetMaster.column(6).search('^' + val + '$', true, false).draw();
        } else {
            tableAsetMaster.column(6).search('').draw();
            // Kembalikan ke default sorting jika di-reset
            tableAsetMaster.order([[1, 'asc'], [4, 'asc'], [6, 'asc']]).draw();
        }
    });
}
});


// function bukaModalSaluran(kode, nama, nomen, hulu, hilir, pj, baik, rr, rb, bap, surveyor, foto, luas) {
//     // 1. Debugging: Cek di console apakah urutan data sudah benar
//     console.log("Data diterima:", {kode, nama, nomen, hulu, hilir, pj, baik, rr, rb, bap, surveyor, foto, luas});

//     // 2. Pembersihan Backdrop (Fix Layar Gelap/Freeze)
//     $('.modal-backdrop').remove();
//     $('body').removeClass('modal-open').css('padding-right', '');

//     // 3. Mapping Data ke Elemen HTML Modal
//     // Menggunakan ID yang sesuai dengan tabel di base.html
//     const setEl = (id, val) => {
//         const el = document.getElementById(id);
//         if (el) el.innerText = val || '-';
//     };

//     setEl('det-header', nama);
//     setEl('det-jenis', kode);
//     setEl('det-nama', nama);
//     setEl('det-nomenklatur', nomen);
//     setEl('det-hulu', hulu);
//     setEl('det-hilir', hilir); // Hilir diisi dari parameter ke-5
//     setEl('det-panjang', pj + ' m');
//     setEl('det-luas', luas + ' Ha'); // Luas diisi dari parameter ke-13
    
//     // Data Kondisi (Detail meteran)
//     setEl('det-baik', baik + ' m');
//     setEl('det-rr', rr + ' m');
//     setEl('det-rb', rb + ' m');
//     setEl('det-bap', bap + ' m');
//     setEl('det-surveyor', surveyor);

//     // 4. Menampilkan Foto
//     const containerFoto = document.getElementById('sal-foto');
//     if (containerFoto) {
//         containerFoto.innerHTML = foto ? 
//             `<img src="${foto}" class="img-fluid rounded border" style="max-height: 200px; object-fit: cover;">` : 
//             '<small class="text-muted">Tidak ada foto dokumentasi</small>';
//     }

//     // 5. Eksekusi Modal
//     const modalEl = document.getElementById('modalSaluranDetail');
//     if (modalEl) {
//         const myModal = bootstrap.Modal.getOrCreateInstance(modalEl);
//         myModal.show();

//         // Listener tambahan untuk memastikan backdrop hilang saat modal muncul
//         modalEl.addEventListener('shown.bs.modal', function () {
//             document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
//             document.body.classList.remove('modal-open');
//             document.body.style.overflow = 'auto';
//         }, { once: true });
//     }
// }

let currentGeoJSONData = null;
let currentNamaSaluran = "Saluran_Irigasi";

function ambilDataDanBukaModal(saluranId, diId) {
    // 1. Bersihkan backdrop agar tidak freeze/gelap
    $('.modal-backdrop').remove();
    $('body').removeClass('modal-open').css('overflow', 'auto');

    // 2. Ambil data Saluran dan Bangunan secara paralel
    Promise.all([
        fetch('/api/daerah-irigasi/').then(res => res.json()),
        fetch(`/api/bangunan/${diId}/?saluran_id=${saluranId}`).then(res => res.json())
    ])
    .then(([allData, resBangunan]) => {
        let dataSaluran = null;
        let namaDI = "-";
        
        // Cari data saluran di dalam list DI dari API
        allData.forEach(di => {
            if (di.saluran_list) {
                let found = di.saluran_list.find(s => s.id == saluranId);
                if (found) {
                    dataSaluran = found;
                    namaDI = di.nama_di;
                }
            }
        });

        if (dataSaluran) {
            const setEl = (id, val) => {
                const el = document.getElementById(id);
                if (el) el.innerHTML = val || '-'; // Gunakan innerHTML agar bisa merender badge HTML
            };

            // I. DATA UMUM & ADMINISTRASI
            setEl('sal-header-title', dataSaluran.nama_saluran);
            setEl('sal-jenis', dataSaluran.kode_aset_saluran_display || dataSaluran.kode_aset_saluran || '-');
            setEl('sal-nama', dataSaluran.nama_saluran);
            setEl('sal-di', namaDI);
            setEl('sal-tingkat', dataSaluran.tingkat_jaringan || 'Teknis');
            setEl('sal-kewenangan', dataSaluran.kewenangan || 'Kabupaten');
            setEl('sal-hulu', dataSaluran.bangunan_hulu_nama);

            // II. DATA TEKNIS & KONDISI
            setEl('sal-panjang', dataSaluran.panjang_saluran + ' m');
            setEl('sal-baik', (dataSaluran.panjang_baik || 0) + ' m');
            setEl('sal-rr', (dataSaluran.panjang_rr || 0) + ' m');
            setEl('sal-rb', (dataSaluran.panjang_rb || 0) + ' m');
            setEl('sal-bap', (dataSaluran.panjang_bap || 0) + ' m');

            
            let kondisiText = dataSaluran.kondisi_aset || '-';
            let badgeClass = 'bg-success';
            
            if (kondisiText === '-') {
                // Fallback hitung otomatis jika API tidak menyediakan kondisi_aset
                let b = parseFloat(dataSaluran.panjang_baik) || 0;
                let rr = parseFloat(dataSaluran.panjang_rr) || 0;
                let rb = parseFloat(dataSaluran.panjang_rb) || 0;
                if ((b + rr + rb) > 0) {
                    if (rb > b && rb > rr) kondisiText = 'RUSAK BERAT';
                    else if (rr > b) kondisiText = 'RUSAK RINGAN';
                    else kondisiText = 'BAIK';
                } else {
                    kondisiText = 'BAIK';
                }
            }

            let kUpper = kondisiText.toUpperCase();
            if (kUpper.includes('RR') || kUpper.includes('RINGAN') || kUpper.includes('SEDANG')) badgeClass = 'bg-warning text-dark';
            if (kUpper.includes('RB') || kUpper.includes('BERAT')) badgeClass = 'bg-danger';
            if (kUpper.includes('BAP') || kUpper.includes('PASANGAN')) badgeClass = 'bg-secondary';

            setEl('sal-kondisi', `<span class="badge ${badgeClass}">${kUpper}</span>`);
            

            // III. DOKUMENTASI
            setEl('sal-geometri', dataSaluran.geometry_data ? 'Tersedia (GeoJSON)' : 'Tidak Ada');
            setEl('sal-surveyor', dataSaluran.surveyor);

            const spanGeometri = document.getElementById('sal-geometri');
            const btnUnduhGeometri = document.getElementById('btn-unduh-geojson');

            if (dataSaluran.geometry_data) {
                // Ada data JSON spasial dari server
                if (spanGeometri) spanGeometri.innerText = 'Tersedia (GeoJSON)';
                if (btnUnduhGeometri) {
                    btnUnduhGeometri.classList.remove('d-none');
                    btnUnduhGeometri.setAttribute('onclick', 'prosesUnduhGeoJSON()');
                }
                // Simpan ke memori untuk diunduh nanti
                currentGeoJSONData = dataSaluran.geometry_data;
                currentNamaSaluran = dataSaluran.nama_saluran;

            } else if (dataSaluran.geojson_url) {
                // Ada link file GeoJSON langsung
                if (spanGeometri) spanGeometri.innerText = 'Tersedia (File URL)';
                if (btnUnduhGeometri) {
                    btnUnduhGeometri.classList.remove('d-none');
                    btnUnduhGeometri.setAttribute('onclick', `window.open('${dataSaluran.geojson_url}', '_blank')`);
                }
                currentGeoJSONData = null;
            } else {
                // Tidak ada data geometri sama sekali
                if (spanGeometri) spanGeometri.innerText = 'Tidak Ada';
                if (btnUnduhGeometri) btnUnduhGeometri.classList.add('d-none');
                currentGeoJSONData = null;
            }

            const containerFoto = document.getElementById('sal-foto');
            if (containerFoto) {
                let photos = dataSaluran.all_photos || []; 
                
                if (photos.length > 0) {
                    let htmlGallery = '';
                    photos.forEach(url => {
                        htmlGallery += `
                            <div class="sal-gallery-item">
                                <a href="${url}" target="_blank">
                                    <img src="${url}" onerror="this.src='/static/img/no-image.png'">
                                </a>
                            </div>`;
                    });
                    containerFoto.innerHTML = htmlGallery;
                    // Tambahkan style inline untuk memastikan lebar container tidak merusak tabel
                    containerFoto.style.display = 'flex';
                } else {
                    containerFoto.innerHTML = '<div class="small text-muted">Tidak ada foto</div>';
                }
            }

            // 3. Tampilkan Modal
            const modalEl = document.getElementById('modalSaluranDetail');
            const myModal = bootstrap.Modal.getOrCreateInstance(modalEl);
            myModal.show();

            // Fix Backdrop
            modalEl.addEventListener('shown.bs.modal', function () {
                document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
            }, { once: true });

        } else {
            alert("Data saluran tidak ditemukan di API");
        }
    })
    .catch(err => {
        console.error("Fetch Error:", err);
        alert("Gagal memuat data");
    });
}


function bukaDetailDiTabel(kodeAset) {
    // 1. Tutup popup peta agar rapi
    if (typeof mapKeseluruhan !== 'undefined' && mapKeseluruhan !== null) {
        mapKeseluruhan.closePopup();
    }

    // 2. Pindah otomatis ke Tab "Komposisi Luasan" tempat tabel itu bersarang
    const tabTrigger = document.querySelector('#chart-tab');
    if (tabTrigger) {
        const tab = bootstrap.Tab.getOrCreateInstance(tabTrigger);
        tab.show();
    }

    // 3. Panggil fungsi GSAP Bapak/Ibu untuk membuka Div "view-detail-distribusi"
    if (typeof showDrillDownDistribusi === "function") {
        showDrillDownDistribusi();
    }

    // 4. Tunggu animasi perpindahan Tab & GSAP selesai (sekitar 500ms), baru proses DataTable-nya
    setTimeout(() => {
        if ($.fn.DataTable.isDataTable('#table-bangunan-master')) {
            const table = $('#table-bangunan-master').DataTable();
            
            // Lakukan pencarian otomatis berdasarkan Kode Aset
            table.search(kodeAset).draw();
            
            // Scroll layar perlahan ke arah tabel (-120px agar judul tabel tidak tertutup navbar atas)
            $('html, body').animate({
                scrollTop: $("#filter-kategori-btn").offset().top - 120
            }, 800);
            
            // [Opsional] Memberi efek kedip kuning/hijau di area tabel agar user langsung fokus
            const tableContainer = $('#table-bangunan-master').closest('.card');
            tableContainer.css({'transition': 'box-shadow 0.3s', 'box-shadow': '0 0 15px rgba(25, 135, 84, 0.8)'});
            setTimeout(() => {
                tableContainer.css('box-shadow', '');
            }, 2500);

        } else {
            console.warn("Tabel #table-bangunan-master belum diinisialisasi.");
        }
    }, 600); // Jeda 600ms wajib ada agar elemen HTML selesai digambar sebelum di-scroll
}

$(document).ready(function() {
    // 1. Inisialisasi DataTable untuk Saluran
   if ($('#table-saluran-master').length) {
        var tableSaluranMaster = $('#table-saluran-master').DataTable({
            "pageLength": 5,
            
            "dom": "<'row mb-2'<'col-md-6'l><'col-md-6 text-end'B>>" +
                   "<'row'<'col-sm-12'tr>>" +
                   "<'row mt-2'<'col-sm-5'i><'col-sm-7'p>>",
                   
            // PERUBAHAN: Tombol Hitam Putih (Monochrome)
            "buttons": [
                { extend: 'copy', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-copy"></i> Copy' },
                { extend: 'excel', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-file-excel"></i> Excel' },
                { extend: 'pdf', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-file-pdf"></i> PDF' },
                { extend: 'print', className: 'btn btn-sm btn-outline-dark', text: '<i class="fas fa-print"></i> Print' }
            ],

            "columnDefs": [
                { "targets": [6, 7, 8, 9], "visible": false, "searchable": false }, 
                { "targets": [10], "orderable": false }
            ],
            
            "order": [[2, "asc"], [4, "desc"]],

            "language": {
                "search": "Cari Saluran:",
                "lengthMenu": "Tampilkan _MENU_ data",
                "info": "Menampilkan _START_ sampai _END_ dari _TOTAL_ saluran",
                "infoEmpty": "Tidak ada data saluran",
                "paginate": {
                    "first": "Pertama",
                    "last": "Terakhir",
                    "next": "Selanjutnya",
                    "previous": "Sebelumnya"
                }
            },

            "initComplete": function () {
                var api = this.api();

                // Isi otomatis dropdown D.I.
                api.column(3).data().unique().sort().each(function (d, j) {
                    if (d && d !== "-") {
                        $('#filter-di-saluran').append('<option value="' + d + '">' + d + '</option>');
                    }
                });

                // PERUBAHAN: Perintah search "Primer" dihapus. 
                // Sekarang semua data muncul, tapi otomatis di-sorting berdasarkan Jenis Saluran.
            },

            "drawCallback": function(settings) {
                initAllTooltips(); 
            }
        });

        tableSaluranMaster.on('order.dt search.dt', function () {
            let i = 1;
            tableSaluranMaster.cells(null, 0, { search: 'applied', order: 'applied' }).every(function (cell) {
                this.data(i++);
            });
        }).draw();

        // 1. Logika Filter D.I.
        $('#filter-di-saluran').on('change', function () {
            var val = $.fn.dataTable.util.escapeRegex($(this).val());
            tableSaluranMaster.column(3).search(val ? '^' + val + '$' : '', true, false).draw();
        });

        // 2. Logika Sorting Kondisi (Prioritas)
        $('#sort-kondisi-saluran').on('change', function () {
            var columnIdx = $(this).val(); 
            if (columnIdx) {
                tableSaluranMaster.order([columnIdx, 'desc']).draw();
            } else {
                // Jika reset, kembalikan sorting ke Jenis Saluran (Kolom 2)
                tableSaluranMaster.order([2, 'asc']).draw();
            }
        });
    }
});

// Aktifkan Bootstrap Tooltip untuk menampilkan Meteran saat Progress Bar di-hover
var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
  return new bootstrap.Tooltip(tooltipTriggerEl)
});


document.addEventListener('DOMContentLoaded', function() {
    // Ambil semua elemen card yang punya class 'card-stats'
    const statCards = document.querySelectorAll('.card-stats');

    statCards.forEach(card => {
        card.addEventListener('click', function() {
            // 1. Hapus class 'card-active' dari semua card statistik lainnya
            statCards.forEach(c => c.classList.remove('card-active'));
            
            // 2. Tambahkan class 'card-active' ke card yang sedang diklik
            this.classList.add('card-active');
        });
    });
});


$(document).on('click', '#btn-toggle-panel', function() {
    const icon = $('#icon-toggle-panel');
    
    // Animasi sembunyikan/tampilkan isi panel (Slide Up/Down)
    $('#panel-aset-body').slideToggle(300);
    
    // Animasi putar balik icon panah
    if (icon.hasClass('fa-chevron-up')) {
        icon.removeClass('fa-chevron-up').addClass('fa-chevron-down');
    } else {
        icon.removeClass('fa-chevron-down').addClass('fa-chevron-up');
    }
});


function prosesUnduhGeoJSON() {
    if (!currentGeoJSONData) {
        alert("Data spasial tidak ditemukan untuk diunduh!");
        return;
    }

    // Ubah JSON object ke text yang rapi
    const dataStr = JSON.stringify(currentGeoJSONData, null, 2);
    
    // Buat objek file (Blob)
    const blob = new Blob([dataStr], { type: "application/geo+json" });
    const url = URL.createObjectURL(blob);

    // Bikin link elemen sementara & trigger download
    const link = document.createElement('a');
    link.style.display = 'none';
    link.href = url;
    
    // Format nama file agar rapi & aman (contoh: Geometri_Sal_Induk_Cihaul.geojson)
    const namaFileAman = currentNamaSaluran ? currentNamaSaluran.replace(/[^a-zA-Z0-9]/g, '_') : 'Saluran';
    link.download = `Geometri_${namaFileAman}.geojson`;
    
    document.body.appendChild(link);
    link.click();
    
    // Hapus elemen & memory setelah selesai
    setTimeout(() => {
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    }, 100);
}
