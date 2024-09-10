//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "../interfaces/errors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**

      ___           ___           ___                         ___           ___         ___           ___
     /\  \         /\__\         /\  \                       /\  \         /\  \       /\  \         /\  \
    |::\  \       /:/ _/_        \:\  \         ___         /::\  \       /::\  \     /::\  \       /::\  \         ___
    |:|:\  \     /:/ /\__\        \:\  \       /\__\       /:/\:\  \     /:/\:\__\   /:/\:\  \     /:/\:\__\       /\__\
  __|:|\:\  \   /:/ /:/ _/_   _____\:\  \     /:/  /      /:/ /::\  \   /:/ /:/  /  /:/  \:\  \   /:/ /:/  /      /:/  /
 /::::|_\:\__\ /:/_/:/ /\__\ /::::::::\__\   /:/__/      /:/_/:/\:\__\ /:/_/:/  /  /:/__/ \:\__\ /:/_/:/__/___   /:/__/
 \:\~~\  \/__/ \:\/:/ /:/  / \:\~~\~~\/__/  /::\  \      \:\/:/  \/__/ \:\/:/  /   \:\  \ /:/  / \:\/:::::/  /  /::\  \
  \:\  \        \::/_/:/  /   \:\  \       /:/\:\  \      \::/__/       \::/__/     \:\  /:/  /   \::/~~/~~~~  /:/\:\  \
   \:\  \        \:\/:/  /     \:\  \      \/__\:\  \      \:\  \        \:\  \      \:\/:/  /     \:\~~\      \/__\:\  \
    \:\__\        \::/  /       \:\__\          \:\__\      \:\__\        \:\__\      \::/  /       \:\__\          \:\__\
     \/__/         \/__/         \/__/           \/__/       \/__/         \/__/       \/__/         \/__/           \/__/



**/

/**
 * @title MentaportVerify
 * @dev Contract allows function to be restricted to users that posess
 * signed authorization from the owner of the contract. This signed
 * message includes the user to give permission to and the contract address to prevent
 * reusing the same authorization message on different contract with same owner.
 **/

contract MentaportVerify is AccessControl, EIP712, MentaportCertificateRegisteryErrors {

    struct MintMessage {
        address account;
        uint256 timestamp;
    }

    string private constant SIGNING_DOMAIN = "Mentaport-Certificate";
    string private constant SIGNATURE_VERSION = "1";
    bytes32 private constant TYPEHASH =
        keccak256(
            "MintMessage(address receiver,uint256 timestamp)"
        );

    /** @dev Signature role is controlled by CONTRACT_ADMIN
     *   Only accounts that its signature can be verified.
     */
     bytes32 public constant CONTRACT_ADMIN = keccak256("CONTRACT_ADMIN");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    /** @dev Minter role to control minting outside minting payed function
     *  - preMinting
     *  - mintByaddress
     * Controled by CONTRACT_ADMIN
     **/
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PROJECT_OWNER_ROLE =
        keccak256("PROJECT_OWNER_ROLE");

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        // Admin role minter is contract admin
        _setRoleAdmin(MINTER_ROLE, CONTRACT_ADMIN);

        // Contract and signer role admin is owner()
        _setRoleAdmin(SIGNER_ROLE, CONTRACT_ADMIN);
        _setRoleAdmin(PROJECT_OWNER_ROLE, CONTRACT_ADMIN);
    }

    modifier onlyValidSigner(
        address _receiver,
        uint256 _timestamp,
        bytes memory _signature
    ) {
        if(!isValidSigner(_receiver, _timestamp, _signature)) {
            revert InvalidSignature();
        }
        _;
    }

    //----------------------------------------------------------------------------
    // Public functions that are View
    // Verifies if message was signed by owner to give access to _add for this contract.
    function isValidSigner(
        address _receiver,
        uint _timestamp,
        bytes memory _signature
    ) public view returns (bool) {
        bytes memory encodedMessage = abi.encode(
            TYPEHASH,
            _receiver,
            _timestamp
        );

        bytes32 message = _hashTypedDataV4(keccak256(encodedMessage));
        address recovered = ECDSA.recover(message, _signature);
        if(!hasRole(SIGNER_ROLE, recovered)) {
            revert InvalidSignature();
        }
        return true;
    }

}
