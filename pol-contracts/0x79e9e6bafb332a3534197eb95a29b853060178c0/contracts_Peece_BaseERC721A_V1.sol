// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import './erc721a_contracts_ERC721A.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_utils_Strings.sol';
import './openzeppelin_contracts_utils_Pausable.sol';

contract Peece_BaseERC721A_V1 is ERC721A, Pausable, Ownable {
    using Strings for uint256;

    // ===== Constantes =====

    string public constant PEECE_VERSION = '0.0.1';

    // ===== Variáveis =====

    /// @dev Número máximo de tokens permitidos por endereço
    uint public maxTokensPerAddress = 0;
    /// @dev Timestamp do início do mint
    uint public startsAt;
    /// @dev Timestamp do final do mint
    uint public endsAt;
    /// @dev Número máximo de tokens
    uint public maxSupply;
    /// @dev Base URI
    string public baseURI;
    /// @dev Flag que indica se o metadado final já foi revelado.
    /// Também pode ser utilizado para não ter metadados diferentes.
    bool public isRevealed;
    /// @dev Número máximo de mints por endereço
    uint public maxMintsPerAddress = 1;
    /// @dev Armazena o número de mints por endereço
    mapping(address => uint) public mintsPerAddress;
    /// @dev Armazena os endereços que podem fazer o mint
    address[] public minters;

    // ===== Erros e eventos =====

    /// @dev Emitido quando o número máximo de tokens por endereço é atingido
    error MaxTokensPerAddressReached();
    /// @dev Emitido quando o número máximo de mints por endereço é atingido
    error MaxMintsPerAddressReached();
    /// @dev Emitido quando o desafio é inválido
    error InvalidChallange();
    /// @dev Emitido quando o sender não tem permissão para fazer o mint
    error UnauthorizedMint();
    /// @dev Emitido quando o mint não está aberto
    error MintNotOpen();
    /// @dev Emitido quando o número máximo de tokens é atingido
    error MaxSupplyReached();

    constructor(
        string memory _name,
        string memory _symbol,
        uint _startsAt,
        uint _endsAt,
        uint _maxSupply,
        string memory __baseURI,
        bool _isRevealed,
        uint _maxMintsPerAddress,
        address _firstMinter,
        uint _firstMintQuantity,
        address[] memory _minters
    ) ERC721A(_name, _symbol) Ownable(_msgSender()) {
        if (_startsAt > 0 && _endsAt > 0) require(_startsAt < _endsAt, 'startsAt must be before endsAt');
        startsAt = _startsAt;
        endsAt = _endsAt;
        maxSupply = _maxSupply;
        baseURI = __baseURI;
        isRevealed = _isRevealed;
        minters = _minters;
        maxMintsPerAddress = _maxMintsPerAddress;
        _mint(_firstMinter, _firstMintQuantity);
    }

    function setMaxTokensPerAddress(uint _maxTokensPerAddress) public onlyOwner {
        maxTokensPerAddress = _maxTokensPerAddress;
    }

    function setStartsAt(uint _startsAt) public onlyOwner {
        startsAt = _startsAt;
    }

    function setEndsAt(uint _endsAt) public onlyOwner {
        endsAt = _endsAt;
    }

    function setMinters(address[] memory _minters) public onlyOwner {
        minters = _minters;
    }

    // ===== Mint =====
    event Mint(address indexed _receiver, uint256 indexed _tokenId, address indexed _minter);

    modifier _onlyMinter() {
        bool isMinter = false;

        for (uint i = 0; i < minters.length; i++) {
            if (minters[i] == _msgSender()) {
                isMinter = true;
                break;
            }
        }

        if (!isMinter) revert UnauthorizedMint();

        _;
    }

    function mintFor(address _address, Challenge memory _challenge) public _onlyMinter {
        // Verifica se o mint está aberto
        verifyTimelock();

        // Verifica o desafio
        verifyChallange(_challenge);

        // Verifica o número máximo de mints por endereço
        if (maxMintsPerAddress > 0 && mintsPerAddress[_address] >= maxMintsPerAddress)
            revert MaxMintsPerAddressReached();

        // Incrementa o número de mints
        mintsPerAddress[_address] += 1;

        // Verifica o maxSupply
        uint tokenId = totalSupply() + 1;
        if (maxSupply > 0 && tokenId > maxSupply) revert MaxSupplyReached();

        // Verifica número máximo de tokens por endereço
        if (maxTokensPerAddress > 0 && balanceOf(_address) >= maxTokensPerAddress) revert MaxTokensPerAddressReached();

        // Faz o mint do NFT
        _safeMint(_address, 1);
        emit Mint(_address, _nextTokenId(), _msgSender());
    }

    /**
     * @dev Verifica as datas limites para o mint dessa coleção.
     */
    function verifyTimelock() internal view {
        if ((startsAt > 0 && block.timestamp < startsAt) || (endsAt > 0 && block.timestamp > endsAt))
            revert MintNotOpen();
    }

    // ===== Desafio =====

    struct Challenge {
        address _address;
        uint256 _timestamp;
        bytes32 _hash;
    }

    /**
     * Previne robôs de cunharem o NFT desenfreadamente.
     *
     * @dev Verifica se o minter fez o desafio corretamente. O desafio consiste
     * de uma string do seguinte formato: keccak256("PEGAE-BASE-V1" + address + timestamp).
     */
    function verifyChallange(Challenge memory _challenge) internal view {
        // Verifica o timestamp do desafio
        if (_challenge._timestamp > block.timestamp) revert InvalidChallange();

        // Verifica o endereço do desafio
        if (_challenge._address != _msgSender()) revert InvalidChallange();

        // Verifica hash do desafio
        bytes32 resultingHash = keccak256(abi.encodePacked('PEGAE-BASE-V1', _msgSender(), _challenge._timestamp));
        if (_challenge._hash != resultingHash) revert InvalidChallange();
    }

    // ===== Metadata ====

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory __baseURI = _baseURI();
        return isRevealed ? string(abi.encodePacked(__baseURI, tokenId.toString(), '.json')) : __baseURI;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory __baseURI) public onlyOwner {
        baseURI = __baseURI;
    }

    function setIsRevealed(bool _isRevealed) public onlyOwner {
        isRevealed = _isRevealed;
    }
}