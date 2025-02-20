// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FileStorage {

    // Struktur untuk menyimpan data file
    struct FileData {
        string cid;
        string name;
    }

    // Mapping untuk menyimpan file berdasarkan cid
    mapping(string => FileData) private files;

    // Event untuk mengemisi informasi file yang disimpan
    event FileStored(address indexed user, string cid, string name);
    event PermitDocsCalled(address indexed user, string cid, string name); // Event baru

    // Fungsi untuk menyimpan file
    function permitDocs(string memory _cid, string memory _name) public returns (bytes32) {
        // Menghasilkan transaction hash yang unik untuk transaksi ini
        bytes32 txHash = keccak256(abi.encodePacked(msg.sender, _cid, block.timestamp));

        // Menyimpan data file di mapping
        files[_cid] = FileData({
            cid: _cid,
            name: _name
        });

        // Emit event untuk informasi lebih lanjut
        emit FileStored(msg.sender, _cid, _name);
        emit PermitDocsCalled(msg.sender, _cid, _name); // Emit event PermitDocsCalled

        return txHash; // Mengembalikan hash transaksi
    }

    // Fungsi untuk mengambil data berdasarkan cid
    function getFileByCid(string memory _cid) public view returns (string memory, string memory) {
        // Pastikan file ditemukan
        require(bytes(files[_cid].cid).length > 0, "File not found!");

        // Mengembalikan informasi file
        FileData memory file = files[_cid];
        return (file.cid, file.name);
    }
}