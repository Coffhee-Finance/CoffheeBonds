// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//contract address on Sepolia:  0x880fe78C2E1bd0Ac2c6580Dc99f47C29107d9884

// Interface for the underlying Bond Standard
interface IERC3475 {
    function safeTransferFrom(address from, address to, uint256 classId, uint256 nonce, uint256 amount) external;
}

contract Frappucino is ERC1155, Ownable {
    IERC3475 public bondContract;

    // Encrypted balances for each Token ID (FHE type euint32)
    // mapping(tokenId => mapping(owner => encryptedBalance))
    mapping(uint256 => mapping(address => euint32)) private _encryptedBalances;

    constructor(address _bondContract) ERC1155("https://api.frappucino.io/metadata/{id}.json") Ownable(msg.sender) {
        bondContract = IERC3475(_bondContract);
    }

    /**
     * @notice Wrap an ERC-3475 Bond into an encrypted ERC-1155 receipt.
     * @param classId The bond class from ERC-3475
     * @param nonce The bond nonce (issuance) from ERC-3475
     * @param publicAmount The number of bonds to lock
     * @param tokenId The ERC-1155 ID to receive as a receipt
     */
    function wrapBond(
        uint256 classId,
        uint256 nonce,
        uint256 publicAmount,
        uint256 tokenId
    ) public {
        // 1. Pull the ERC-3475 bond into this vault
        bondContract.safeTransferFrom(msg.sender, address(this), classId, nonce, publicAmount);

        // 2. Convert public amount to encrypted amount (euint32)
        euint32 encryptedAmount = TFHE.asEuint32(uint32(publicAmount));

        // 3. Update the encrypted balance
        _encryptedBalances[tokenId][msg.sender] = TFHE.add(_encryptedBalances[tokenId][msg.sender], encryptedAmount);

        // 4. Grant permission for the user to view their own balance
        TFHE.allow(_encryptedBalances[tokenId][msg.sender], msg.sender);

        // 5. Emit standard ERC-1155 mint event (publicly shows logic, not the new secret balance)
        _mint(msg.sender, tokenId, publicAmount, "");
    }

    /**
     * @notice Confidential Transfer of the wrapper tokens.
     */
    function confidentialTransfer(
        address to,
        uint256 tokenId,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public {
        euint32 amount = TFHE.asEuint32(encryptedAmount, inputProof);
        
        // FHE requirement: subtract from sender, add to receiver
        _encryptedBalances[tokenId][msg.sender] = TFHE.sub(_encryptedBalances[tokenId][msg.sender], amount);
        _encryptedBalances[tokenId][to] = TFHE.add(_encryptedBalances[tokenId][to], amount);

        TFHE.allow(_encryptedBalances[tokenId][msg.sender], msg.sender);
        TFHE.allow(_encryptedBalances[tokenId][to], to);
    }

    // Standard ERC-1155 balanceOf will return 0 or be disabled to maintain privacy
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return 0; 
    }
}