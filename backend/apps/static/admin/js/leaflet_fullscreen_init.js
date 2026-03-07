window.addEventListener('map:init', function (e) {
    var map = e.detail.map;

    // Pastikan plugin fullscreen sudah ter-load, lalu tambahkan ke peta
    if (typeof L.Control.Fullscreen !== 'undefined') {
        map.addControl(new L.Control.Fullscreen({
            position: 'topleft', // Taruh di kiri atas, gabung dengan zoom control
            title: {
                'false': 'Lihat Layar Penuh',
                'true': 'Keluar Layar Penuh'
            }
        }));
    } else {
        console.warn("Script Fullscreen belum ter-load dari settings.");
    }
});