//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

struct Project {
    uint128 id;
    uint128 maxSupply;
    uint128 totalMinted;
    bool paused;
    address owner;
    string ownerName;
    string projectName;
    string projectBaseURI;
}

struct Certificate {
    string certificateId;
    uint256 tokenId;
    uint256 timestamp;
    string c2paManifestURI;
    string tokenURI;
}

struct ProjectRequest {
    string projectName;
    uint128 maxSupply;
    address owner;
    string ownerName;
    string projectBaseURI;
}

struct UpdtateProjectRequest {
    string projectName;
    uint128 maxSupply;
    string ownerName;
    string projectBaseURI;
}

struct MintRequest {
    uint256 timestamp;
    string tokenURI;
    string certificateId;
    string c2paManifestURI;
}

interface IMentaportCertificateRegistry {
    /**
     * @dev Emitted when a merkle root is updated
     */
    event ProjectMerkleRootUpdated(
        uint128 indexed projectId,
        bytes32 indexed oldRoot,
        bytes32 indexed newRoot
    );

    /**
     * @dev Emitted when a project is created
     */
    event ProjectAdded(uint128 indexed projectId, address creator);

    /**
     * @dev Emitted when a project owner is updated
     */
    event ProjectOwnerUpdated(
        uint128 indexed projectId,
        address oldProjectOwner,
        address newProjectOwner
    );

    /**
     * @dev Emitted when a tokenId is updated
     */
    event TokenUriUpdated(
        string indexed tokenUri,
        uint256 indexed tokenId,
        uint128 indexed projectId
    );

    /**
     * @dev Emitted when a project max supply is updated
     */
    event ProjectMaxSupplyUpdated(
        uint128 indexed projectId,
        uint256 newMaxSupply
    );

    /**
     * @dev Emitted when a project Base URI is updated
     */
    event ProjectUriUpdated(
        uint128 indexed projectId,
        string previousProjectUri,
        string newProjectUri
    );

    /**
     * @dev Emitted when a project Base URI is updated
     */
    event ProjectUpdated(
        uint128 indexed projectId
    );

    /**
     * @dev Emitted when a project is paused/unpaused
     */
    event ProjectPaused(uint128 indexed projectId, bool paused);

    /**
     * @dev Emitted when the registry is paused/unpaused
     */
    event RegistryPaused(address indexed sender, bool paused);

    /**
     * @dev Emitted when a user mints certificate from project
     */
    event MintCertificateFromProject(
        uint256 indexed tokenId,
        address indexed receiver,
        string indexed certificateId,
        uint128 projectId
    );
}
