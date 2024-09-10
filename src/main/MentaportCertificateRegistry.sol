//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "../interfaces/IMentaportCertificateRegistry.sol";
import "../interfaces/errors.sol";
import "./MentaportVerify.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title A certificate registry contract that allows users to issue content autheticity certificates in the form of SoulBound NFTs
 * @author Mentaport
 */
contract MentaportCertificateRegistry is 
    ERC721Enumerable, 
    ERC721URIStorage,
    MentaportVerify,
    Pausable,
    ReentrancyGuard,
    IMentaportCertificateRegistry 
{

    /// keeps track of total number of projects created
    uint128 public totalProjects;

    /// projectId => Project
    mapping(uint128 => Project) private projects;

    /// projectId => address => balance
    mapping(uint128 => mapping(address => uint128)) public balanceOfProject;

    /// hash of certificate Id => certificates
    mapping(bytes32 => Certificate) private certificates;

    /// token Id => certificate Id
    mapping(uint256 => string) public certificateByToken;

    /// checks that caller is the valid project owner
    modifier onlyProjectOwner(uint128 _projectId) {
        if(msg.sender != projects[_projectId].owner) {
            revert InvalidProjectOwner(_projectId, projects[_projectId].owner);
        }
        _;
    }

    /// checks that project is not paused
    modifier whenProjectNotPaused(uint128 _projectId) {
        if(projects[_projectId].paused) {
            revert ProjectIsPaused(_projectId);
        }
        _;
    }

    /// checks that project is paused
    modifier whenProjectPaused(uint128 _projectId) {
        if(!projects[_projectId].paused) {
            revert ProjectIsUnpaused(_projectId);
        }
        _;
    }

    /// checks that an address is not the zero address for owner address
    modifier notZeroAddress(address _address) {
        if (_address == address(0)) {
            revert ZeroAddressUsed();
        }
        _;
    }

    /// checks that string is not empty for setting name, token URI or project URI
    modifier notEmptyString(string memory _value) {
        if (bytes(_value).length == 0) {
            revert EmptyStringUsed();
        }
        _;
    }

    /// checks that value is not zero for max supply value
    modifier notZeroValue(uint128 _value) {
        if (_value == 0) {
            revert ZeroValueUsed();
        }
        _;
    }

    /// checks that project does not exist based on id
    modifier notExistingProject(uint128 _id) {
        if (_id >= totalProjects) {
            revert NonExistingProject(_id);
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _minter,
        address _signer
    ) ERC721(_name, _symbol)
    {
        // Grant roles to specified accounts
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CONTRACT_ADMIN, _admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONTRACT_ADMIN, msg.sender);

        _grantRole(MINTER_ROLE, _minter);
        // contract owner and _signer can sign contracts
        _grantRole(SIGNER_ROLE, msg.sender);
        _grantRole(SIGNER_ROLE, _signer);
    }

    /**
    * @dev Mints a content certificate to the project owner's wallet.
    * 
    * Requirements:
    * - The contract must not be paused.
    * - The project must not be paused.
    * - The caller must have the MINTER_ROLE.
    * - The project must exist.
    *
    * @param _projectId The ID of the project from which to mint the certificate.
    * @param _mintRequest The request details needed to mint the certificate.
    *
    * @return tokenId The ID of the newly minted token.
    */
    function mintCertificate(
        uint128 _projectId,
        MintRequest calldata _mintRequest
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        whenProjectNotPaused(_projectId)
        onlyRole(MINTER_ROLE)
        notExistingProject(_projectId)
        returns (uint256 tokenId)
    {
        Project storage project = projects[_projectId];
        _isProjectMaxSupplyCompliant(1, project);

        balanceOfProject[_projectId][project.owner] += 1;
        uint128 totalMinted = project.totalMinted + 1;
        project.totalMinted = totalMinted;

        tokenId = _generateTokenId(_projectId, totalMinted);
        _mintNFT(
            project.owner,
            _mintRequest.tokenURI,
            tokenId
        );

        bytes32 key = keccak256(abi.encodePacked(_mintRequest.certificateId));
        certificates[key] = Certificate(_mintRequest.certificateId, tokenId, block.timestamp, _mintRequest.c2paManifestURI, _mintRequest.tokenURI);
        certificateByToken[tokenId] = _mintRequest.certificateId;

        emit MintCertificateFromProject(
            tokenId,
            project.owner,
            _mintRequest.certificateId,
            _projectId
        );
    }

    // Internal functions
    /**
     * @dev Internal mint nft with unique tokenURI
     */
    function _mintNFT(
        address _receiver,
        string memory _tokenURI,
        uint256 _newTokenId
    ) internal {
        _safeMint(_receiver, _newTokenId);
        _setTokenURI(_newTokenId, _tokenURI);
    }

    /**
     * @notice Adds new project to registry
     * @param _projectRequest Project request
     */
    function addProject(
        ProjectRequest memory _projectRequest
    ) 
        external 
        onlyRole(CONTRACT_ADMIN) 
        notZeroValue(_projectRequest.maxSupply)
        notZeroAddress(_projectRequest.owner)
        notEmptyString(_projectRequest.ownerName)
        notEmptyString(_projectRequest.projectName)
        notEmptyString(_projectRequest.projectBaseURI)
        whenNotPaused
        returns (uint128 projectId)
    {
        if (!hasRole(PROJECT_OWNER_ROLE, _projectRequest.owner)) {
            _grantRole(PROJECT_OWNER_ROLE, _projectRequest.owner);
        }
        if(totalProjects >= type(uint128).max) {
            revert MaxNumberProjectsReached(totalProjects);
        }

        projectId = totalProjects;

        projects[projectId] = Project({
            id: projectId,
            maxSupply: _projectRequest.maxSupply,
            paused: false,
            owner: _projectRequest.owner,
            ownerName: _projectRequest.ownerName,
            projectName: _projectRequest.projectName,
            projectBaseURI: _projectRequest.projectBaseURI,
            totalMinted: 0
        });

        totalProjects = projectId + 1;
        emit ProjectAdded(projectId, msg.sender);
        return projectId;
    }

    /**
     * @notice Update the project
     * @param _projectId Project Id to update
     * @param _updateProjectRequest Project request
     */
    function updateProject(
        uint128 _projectId,
        UpdtateProjectRequest memory _updateProjectRequest
    )
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectNotPaused(_projectId)
        notExistingProject(_projectId)
        notZeroValue(_updateProjectRequest.maxSupply)
        notEmptyString(_updateProjectRequest.ownerName)
        notEmptyString(_updateProjectRequest.projectName)
        notEmptyString(_updateProjectRequest.projectBaseURI)
    {
        Project storage project = projects[_projectId];
        if(_updateProjectRequest.maxSupply < project.totalMinted) {
            revert InvalidProjectMaxSupply(_projectId, _updateProjectRequest.maxSupply, project.totalMinted);
        }
        project.ownerName = _updateProjectRequest.ownerName;
        project.projectName = _updateProjectRequest.projectName;
        project.projectBaseURI = _updateProjectRequest.projectBaseURI;
        project.maxSupply = _updateProjectRequest.maxSupply;
        emit ProjectUpdated(_projectId);
    }

    /**
     * @notice Update the project owner
     * @param _projectId Project Id to update
     * @param _newProjectOwner New project owner address
     * @param _newProjectOwnerName New project owner name
     */
    function updateProjectOwner(
        uint128 _projectId,
        address _newProjectOwner,
        string memory _newProjectOwnerName
    )
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectNotPaused(_projectId)
        notExistingProject(_projectId)
        notZeroAddress(_newProjectOwner)
        notEmptyString(_newProjectOwnerName)
    {
        address owner = projects[_projectId].owner;
        if(owner == _newProjectOwner) {
            revert AlreadyProjectOwner(_projectId, _newProjectOwner);
        }
        projects[_projectId].owner = _newProjectOwner;
        projects[_projectId].ownerName = _newProjectOwnerName;
        emit ProjectOwnerUpdated(_projectId, owner, _newProjectOwner);
    }


    /**
     * @notice Update the project mint max supply
     * @param _projectId Project Id to update
     * @param _newMaxSupply New project mint max supply
     */
    function updateProjectMaxSupply(
        uint128 _projectId,
        uint128 _newMaxSupply
    )
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectNotPaused(_projectId)
        notExistingProject(_projectId)
        notZeroValue(_newMaxSupply)
    {
        uint128 totalMinted = projects[_projectId].totalMinted;
        if(_newMaxSupply < totalMinted) {
            revert InvalidProjectMaxSupply(_projectId, _newMaxSupply, totalMinted);
        }
        projects[_projectId].maxSupply = _newMaxSupply;
        emit ProjectMaxSupplyUpdated(_projectId, _newMaxSupply);
    }

    /**
     * @notice Update the project metadata URI
     * @param _projectId Project Id to update
     * @param _newProjectBaseURI New project metadata Base URI
     */
    function updateProjectBaseURI(
        uint128 _projectId,
        string memory _newProjectBaseURI
    )
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectNotPaused(_projectId)
        notExistingProject(_projectId)
        notEmptyString(_newProjectBaseURI)
    {
        string memory _previousProjectUri =  projects[_projectId].projectBaseURI;
        projects[_projectId].projectBaseURI = _newProjectBaseURI;
        emit ProjectUriUpdated(_projectId, _previousProjectUri, _newProjectBaseURI);
    }

    /**
     * @notice Updates the token URI for a given `_tokenId`.
     * @param _tokenId Token ID to be queried.
     * @param _tokenUri Token URI for the tokenId to update
     */
    function updateTokenUri(
        uint256 _tokenId,
        string memory _tokenUri
    )
        external
        onlyRole(CONTRACT_ADMIN)
        notEmptyString(_tokenUri)
    {
        address owner = _ownerOf(_tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        _setTokenURI(_tokenId, _tokenUri);

        bytes32 key = keccak256(abi.encodePacked(certificateByToken[_tokenId]));
        certificates[key].tokenURI = _tokenUri;

        emit TokenUriUpdated(
            _tokenUri,
            _tokenId,
            getProjectIdFromTokenId(_tokenId)
        );
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable, ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        address from = _ownerOf(tokenId);
        if(!(from == address(0) || to == address(0))) {
            revert NonTransferableToken(tokenId);
        }
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Pause project.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The function must called by the project owner.
     */
    function pauseProject(
        uint128 _projectId
    )
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectNotPaused(_projectId)
    {
        projects[_projectId].paused = true;
        emit ProjectPaused(_projectId, true);
    }

    /**
     * @dev Unpause project.
     *
     * Requirements:
     * - The contract must not be unpaused.
     * - The function must called by the project owner.
     */
    function unpauseProject(
        uint128 _projectId
    ) 
        external
        onlyRole(CONTRACT_ADMIN)
        whenProjectPaused(_projectId)
    {
        projects[_projectId].paused = false;
        emit ProjectPaused(_projectId, false);
    }

    /**
     * @dev Pause registry.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The function must called by the owner.
     */
    function pauseRegistry() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit RegistryPaused(msg.sender, true);
    }

    /**
     * @dev Unpause registry.
     *
     * Requirements:
     * - The contract must not be unpaused.
     * - The function must called by the owner.
     */
    function unpauseRegistry() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit RegistryPaused(msg.sender, false);
    }

    /**
     * @notice Get a project data
     * @param _projectId Project Id to fetch
     * @return total mints in the project
     */
    function getProjectTotalMints(
        uint128 _projectId
    ) external view returns (uint128) {
        return projects[_projectId].totalMinted;
    }

    /**
     * @notice Gets the project ID for a given `_tokenId`.
     * @param _tokenId Token ID to be queried.
     * @return _projectId Project ID for given `_tokenId`.
     */
    function getProjectIdFromTokenId(
        uint256 _tokenId
    ) public pure returns (uint128 _projectId) {
        return uint128(_tokenId >> 128);
    }

    /**
     * @notice Get a project info
     * @param _projectId Project Id to fetch
     * @return Project
     */
    function getProject(
        uint128 _projectId
    ) external view returns (Project memory) {
        return projects[_projectId];
    }

    /**
     * @notice Get a certificate info
     * @param _certificateId Certificate Id to fetch
     * @return cert Certificate object
     */
    function getCertificate(
        string memory _certificateId
    ) public view returns (Certificate memory) {
        bytes32 key = keccak256(abi.encodePacked(_certificateId));
        return certificates[key];
    }

    /**
    * @dev withdraws the contract balance and send it to the mentport account.
    * @param _receiver Wallet address that will receive the funds
    */
    function withdraw(address _receiver) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if(address(0) == _receiver) {
            revert ZeroAddressUsed();
        }
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert InsufficientBalance();
        }

        (bool sent, ) = payable(_receiver).call{value: balance}('');
        if(!sent) {
            revert WithdrawFailed();
        }
    }

    /**
     * Fallback function that allows the contract to receive ETH.
     */
    receive() external payable {}

    //////////////////////////////////////////////////////////////////
    // Internal Functions

    /**
     * @notice Generates the token ID for a given `_project`.
     * @param _projectId Project ID to mint NFT from.
     * @param _totalMinted Total NFT minted from a Project ID.
     * @return _tokenId Token of the NFT for the given`_projectId`.
     * E.g if _projectId = 1, in hex(0x00000000000000000000000000000001) and _totalMinted = 234, in hex(0x000000000000000000000000000000ea)
     *      _tokenId = 340282366920938463463374607431768211690
     *      this _tokenId in hex is 0x00000000000000000000000000000001000000000000000000000000000000ea
     */
    function _generateTokenId(
        uint128 _projectId,
        uint128 _totalMinted
    ) internal pure returns (uint256 _tokenId) {
        _tokenId = (uint256(_projectId) << 128) | uint256(_totalMinted);
    }

    /**
     * @dev checks that the mint complies with project limit on max supply
     * @param _amount the amount of NFT to mint
     * @param _project the project to mint an NFT from
     */
    function _isProjectMaxSupplyCompliant(
        uint128 _amount,
        Project memory _project
    ) internal pure {
        if(_project.totalMinted + _amount > _project.maxSupply) {
            revert ProjectMaxSupplyExceeded(_project.id, _project.maxSupply, _amount);
        }
    }

}
