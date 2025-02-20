pragma solidity >0.8.0;

import "./contracts_token_IERC20.sol";
import "./contracts_utils_IELFCore.sol";
import "./contracts_utils_Strings.sol";

import "./contracts_security_PausableV2.sol";

/**
 * @title ELFSacrifice
 * @dev This contract allows users to sacrifice an elf to get buff in game.
 * Sacrificing an elf requires the user to burn COE and store ROE.
 * It also allows the admin to set the roe and coe range for sacrifice and withdraw roe.
 */
contract ELFSacrifice is PausableV2 {
    using Strings for uint256;
    address DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256[2] roeRange;
    uint256[2] coeRange;

    event ELFSacrificed(
        uint256 time,
        address indexed user,
        uint256 roeAmt,
        uint256 coeAmt,
        string elfAttr,
        uint256 grade,
        bool isEgg
    );

    IERC20 public ROE;
    IERC20 public COE;
    IELFCore public ELF;

    /// @dev Operators who can set ROE/COE range.
    address[] ops;
    mapping(address => bool) isOp;

    modifier onlyOp() {
        require(isOp[msg.sender], "ELFSacrifice: not operator");
        _;
    }

    constructor(IERC20 _roe, IERC20 _coe, IELFCore _elf) {
        ROE = _roe;
        COE = _coe;
        ELF = _elf;
    }

    /**
     * @dev Sacrifice an elf to get buff in game
     * @param _tokenId The elf tokenId
     * @param _roeAmount The amount of roe to store
     * @param _coeAmount The amount of coe to burn
     */
    function sacrifice(
        uint256 _tokenId,
        uint256 _roeAmount,
        uint256 _coeAmount
    ) external {
        require(ELF.ownerOf(_tokenId) == msg.sender, "ELFSacrifice: Not owner");

        if (
            _roeAmount < roeRange[0] ||
            _roeAmount > roeRange[1] ||
            _coeAmount < coeRange[0] ||
            _coeAmount > coeRange[1]
        ) {
            revert("ELFSacrifice: ROE/COE out of range");
        }

        // store roe
        ROE.transferFrom(msg.sender, address(this), _roeAmount);
        // transfer to dead address or coe admin address
        COE.transferFrom(msg.sender, DEAD, _coeAmount);
        // transfer elf to contract
        ELF.transferFrom(msg.sender, address(this), _tokenId);

        (, , , uint256 gene, , ) = ELF.gainELF(_tokenId);
        string[] memory elfAttrs = _elfGene(gene);
        string memory mainAttr = elfAttrs[0];

        uint256 grade = 0;
        for (uint256 i = 1; i < elfAttrs.length; ) {
            if (Strings.equal(elfAttrs[i], mainAttr)) {
                ++grade;
            }

            unchecked {
                ++i;
            }
        }

        bool isEgg = ELF.isHatched(_tokenId);

        emit ELFSacrificed(
            block.timestamp,
            msg.sender,
            _roeAmount,
            _coeAmount,
            mainAttr,
            grade,
            !isEgg
        );
    }

    /**
     * @dev Get the roe range for sacrifice
     * @return minRoe The minimum roe
     * @return maxRoe The maximum roe
     */
    function getRoeRange() public view returns (uint256, uint256) {
        return (roeRange[0], roeRange[1]);
    }

    /**
     * @dev Get the coe range for sacrifice
     * @return minCoe The minimum coe
     * @return maxCoe The maximum coe
     */
    function getCoeRange() public view returns (uint256, uint256) {
        return (coeRange[0], coeRange[1]);
    }

    /**
     * @dev Set the roe range for sacrifice
     * @param _minRoe The minimum roe
     * @param _maxRoe The maximum roe
     */
    function setRoeRange(uint256 _minRoe, uint256 _maxRoe) public onlyOp {
        roeRange[0] = _minRoe;
        roeRange[1] = _maxRoe;
    }

    /**
     * @dev Set the coe range for sacrifice
     * @param _minCoe The minimum coe
     * @param _maxCoe The maximum coe
     */
    function setCoeRange(uint256 _minCoe, uint256 _maxCoe) public onlyOp {
        coeRange[0] = _minCoe;
        coeRange[1] = _maxCoe;
    }

    /**
     * @dev Withdraw roe from contract
     * @param _amount The amount of roe to withdraw
     */
    function withdrawROE(uint256 _amount) external onlySuperAdmin {
        require(ROE.balanceOf(address(this)) > _amount, "Insufficient balance");
        ROE.transfer(msg.sender, _amount);
    }

    /**
     * @dev Slice gene into 7 parts
     * @param _gene The elf's gene to slice
     * @return _attrs 7 elf attributes, water, fire...etc
     */
    function _elfGene(uint256 _gene) internal pure returns (string[] memory) {
        require(_gene > 0, "Invalid input gene");
        string[] memory _attrs = new string[](7);

        bytes memory geneBytes = bytes(_gene.toString());
        uint256 len = 2;

        for (uint256 i = 0; i < 7; ) {
            bytes memory buffer = new bytes(len);
            for (uint256 j = 1; j < len; ) {
                buffer[j] = geneBytes[i * 9 + j];
                unchecked {
                    j++;
                }
            }
            _attrs[i] = string(buffer);
            unchecked {
                ++i;
            }
        }

        require(_attrs.length == 7, "Invalid output gene");
        return _attrs;
    }

    /**
     * @dev Set operator
     * @param op The operator address
     * @param tf True for add, false for remove
     */
    function setOps(address op, bool tf) external onlySuperAdmin {
        if (isOp[op] != tf) {
            isOp[op] = tf;
            if (tf) {
                ops.push(op);
            } else {
                // remove element from ops
                uint256 i;
                uint256 l = ops.length;
                while (i < l) {
                    if (ops[i] == op) break;
                    i++;
                }
                ops[i] = ops[l - 1];
                ops.pop();
            }
        }
    }
}