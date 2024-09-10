// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Custom Errors
 * Interface of the custom errors for MentaportCertificateRegistery and MentaportVerify contracts.
 */
interface MentaportCertificateRegisteryErrors {

    /**
     * @dev Indicates that the sender is not the valid project owner.
     * @param projectId The project Id.
     * @param owner Address of project owner.
     */
    error InvalidProjectOwner(uint128 projectId, address owner);

    /**
     * @dev Indicates that the sender is already the project owner.
     * @param projectId The project Id.
     * @param owner Address of project owner.
     */
    error AlreadyProjectOwner(uint128 projectId, address owner);

    /**
     * @dev Indicates that the project has been paused and actions are suspended.
     * @param projectId The project Id.
     */
    error ProjectIsPaused(uint128 projectId);

    /**
     * @dev Indicates that the project has been already unpaused.
     * @param projectId The project Id.
     */
    error ProjectIsUnpaused(uint128 projectId);

    /**
     * @dev Indicates that the provided signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev Indicates that contract balance withdrawal failed.
     */
    error WithdrawFailed();

    /**
     * @dev Indicates that the contract balance is 0.
     */
    error InsufficientBalance();

    /**
     * @dev Indicates that zero address has been supplied as a parameter.
     */
    error ZeroAddressUsed();

    /**
     * @dev Indicates that zero value has been supplied as one of the parameters.
     */
    error ZeroValueUsed();

    /**
     * @dev Indicates that empty string has been supplied as a parameter.
     */
    error EmptyStringUsed();

    /**
     * @dev Indicates that provided project Id does not exist.
     * @param projectId The project Id.
     */
    error NonExistingProject(uint128 projectId);

    /**
     * @dev Indicates that the project with provided project Id has reached the max supply.
     * @param projectId The project Id.
     * @param maxSupply The project specified max supply.
     * @param amount The requested amount to be minted.
     */
    error ProjectMaxSupplyExceeded(uint128 projectId, uint128 maxSupply, uint128 amount);

    /**
     * @dev Indicates that the new max supply for the project Id is below total minted tokens.
     * @param projectId The project Id.
     * @param newMaxSupply The project specified new max supply.
     * @param totalMinted The total number of tokens minted in the project.
     */
    error InvalidProjectMaxSupply(uint128 projectId, uint128 newMaxSupply, uint128 totalMinted);

    /**
     * @dev Indicates that the max number of projects in the contract has been reached.
     * @param totalProjects The total number of projects.
     */
    error MaxNumberProjectsReached(uint128 totalProjects);

    /**
     * @dev Indicates that token is non transferable since it is a SoulBound Token.
     * @param tokenId The token Id that was intended to be transferred.
     */
    error NonTransferableToken(uint256 tokenId);

}