var irigasiTable;

function fixIrigasiTable() {
    if ($.fn.DataTable.isDataTable('#irigasiTable')) {
        irigasiTable.columns.adjust();
    }
}

$(document).ready(function() {
    // Inisialisasi Tabel Utama (Daftar DI)
    if ($('#irigasiTable').length > 0) {
        irigasiTable = $('#irigasiTable').DataTable({ // Simpan ke variabel global irigasiTable
            "pageLength": 5,
            "lengthMenu": [5, 10, 25, 50],
            "order": [[0, "asc"]],
            "autoWidth": false,
            "language": {
                "url": "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json"
            }
        });
    }

    // FUNGSI LOAD TABEL SALURAN
    function loadSaluranTable(diId) {
        if ($.fn.DataTable.isDataTable('#tabelSaluran')) {
            $('#tabelSaluran').DataTable().destroy();
        }

        $('#tabelSaluran').DataTable({
            ajax: {
                url: `/api/saluran/${diId}/`,
                dataSrc: 'data' // Pastikan backend membungkus array dalam kunci 'data'
            },
            pageLength: 5, // PERMINTAAN: Tampilan per 5 halaman
            lengthMenu: [5, 10, 25, 50],
            columns: [
                { data: null, render: (data, type, row, meta) => meta.row + 1 }, // No
                { data: 'nama_saluran', defaultContent: '-' },
                { data: 'nomenklatur', defaultContent: '-' },
                { data: 'bangunan_hulu', defaultContent: '-' },
                { data: 'bangunan_hilir', defaultContent: '-' },
                { data: 'kode_saluran', defaultContent: '-' },
                { 
                    // PERMINTAAN: Foto link & open in new tab
                    data: 'foto', 
                    defaultContent: '', // Menangani jika field 'foto' tidak ada di JSON
                    render: function(data) {
                        if (data) {
                            return `<a href="${data}" target="_blank" class="btn btn-xs btn-primary">
                                        <i class="fas fa-external-link-alt"></i> Lihat Foto
                                    </a>`;
                        }
                        return '<span class="text-muted small">Tidak ada foto</span>';
                    }
                },
                { data: 'jumlah_lining', defaultContent: '0' },
                { data: 'panjang_saluran', defaultContent: '0' },
                { data: 'luas_layanan', defaultContent: '0' },
                { data: 'fungsi_bangunan_sipil', defaultContent: '-' },
                { data: 'fungsi_jalan_inspeksi', defaultContent: '-' },
                { data: 'prioritas', defaultContent: '-' },
                { 
                    data: 'kondisi_aset',
                    render: function(data) {
                        let color = data === 'BAIK' ? 'bg-success' : (data === 'SEDANG' ? 'bg-warning text-dark' : 'bg-danger');
                        return `<span class="badge ${color}">${data || 'N/A'}</span>`;
                    }
                },
                { data: 'nilai_persen', render: (data) => (data || 0) + '%' },
                { data: null, defaultContent: '<button class="btn btn-sm btn-warning"><i class="fas fa-edit"></i></button>' }
            ],
            scrollX: true,
            fixedColumns: { left: 2 },
            dom: 'Bfrtip',
            buttons: ['excel', 'print'],
            language: {
                url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/id.json"
            }
        });
    }

    // TRIGGER SAAT TAB SALURAN DIKLIK
    $('button[id="modal-saluran-tab"]').on('shown.bs.tab', function () {
        // Ambil ID DI dari elemen yang menyimpan ID saat ini (misal dari input hidden di modal)
        // Pastikan Anda punya elemen dengan id="id_di_aktif" di HTML modal Anda
        let diId = $('#id_di_aktif').val(); 
        
        if(diId) {
            loadSaluranTable(diId);
        } else {
            console.error("ID DI Aktif tidak ditemukan di input #id_di_aktif");
        }
    });

    function loadBangunanTable(diId) {
        if ($.fn.DataTable.isDataTable('#tabelBangunan')) {
            $('#tabelBangunan').DataTable().destroy();
        }

        $('#tabelBangunan').DataTable({
            ajax: {
                url: `/api/bangunan/${diId}/`,
                dataSrc: 'data'
            },
            pageLength: 5, 
            columns: [
                { data: null, render: (data, type, row, meta) => meta.row + 1 },
                { data: 'nama_bangunan', defaultContent: '-' }, // Sesuaikan nama field
                { data: 'nomenklatur', defaultContent: '-' },
                { 
                    data: 'kondisi_aset', // Sesuaikan nama field
                    render: function(data) {
                        let color = data === 'BAIK' ? 'bg-success' : 'bg-warning text-dark';
                        return `<span class="badge ${color}">${data || '-'}</span>`;
                    }
                },
                { 
                    data: null,
                    render: function(data, type, row) {
                        const lat = row.latitude;
                        const lon = row.longitude;
                        const nama = row.nama_bangunan.replace(/'/g, "\\'"); // Escape tanda kutip
                        return `<a href="javascript:void(0)" 
                                onclick="focusKePeta(${lat}, ${lon}, '${nama}')" 
                                class="text-primary fw-bold">
                                <i class="fa-solid fa-location-dot"></i> ${lat}, ${lon}
                                </a>`;
                    }
                },
                { 
                    data: 'foto_aset', // Sesuaikan nama field
                    render: function(data) {
                        if (data) {
                            return `<a href="/media/${data}" target="_blank" class="btn btn-xs btn-primary">
                                        <i class="fa-solid fa-up-right-from-square"></i> Lihat Foto
                                    </a>`;
                        }
                        return '<span class="text-muted small">No Photo</span>';
                    }
                }
            ]
        });
    }

    

    // Trigger saat Tab Bangunan diklik
    $('#modal-bangunan-tab').on('shown.bs.tab', function () {
        const diId = $('#id_di_aktif').val();
        loadBangunanTable(diId);
    });
});