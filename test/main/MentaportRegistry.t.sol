//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {
    Project,
    MintRequest,
    ProjectRequest,
    UpdtateProjectRequest,
    Certificate,
    MentaportCertificateRegistry
} from "../../src/main/MentaportCertificateRegistry.sol";
import "../../src/interfaces/errors.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";


contract MentaportRegistryTest is Test {
    using ECDSA for bytes32;

    string public constant _name = "MentaportCertificateRegistry";
    string public constant _symbol = "MER";
    //makeAddr creates an address derived from the provided name.
    address public _admin = makeAddr("admin");
    address public _minter = makeAddr("minter");
    address public _signer = makeAddr("signer");
    address public _owner = makeAddr("owner");
    address public _newAccount = makeAddr("newAccount");
    address public notProjectOwner = makeAddr("notProjectOwner");
    address public mentaportAccount = makeAddr("mentaportAccount");
    address public nonSigner = makeAddr("nonSigner");

    //makeAccount: creates a struct containing both a labeled address and the corresponding private key
    Account public signerA = makeAccount("signerA");
    Account public signerB = makeAccount("signerB");
    Account public InvalidSigner = makeAccount("InvalidSigner");
    Account public projectOwner1 = makeAccount("projectOwner1");
    Account public projectOwner2 = makeAccount("projectOwner2");
    string public projectUri = "https://project_nemo.path/";
    string public c2paManifestURI = "https://certificate.path/";

    MentaportCertificateRegistry public mentaportRegistry;
    ProjectRequest public projectRequest = ProjectRequest({
        projectName: "NFT Collection",
        ownerName: "Nemo",
        maxSupply: 10,
        projectBaseURI: projectUri,
        owner: projectOwner1.addr
    });

    ////////////////////////////////// Main Functionality Section //////////////////////////////////
    ///// 1. deploy contract
    ///// 2. pause registry
    ///// 3. unpause registry
    ///// 4. try to Pause Registry When Already Pause
    ///// 5. try to Unpause Registry When Already Unpause
    ///// 6. try to Pause Registry by Non Contract admin
    ///// 7. try to Unpause Registry by Non Contract Admin
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function setUp() public {
        mentaportRegistry = new MentaportCertificateRegistry(
            _name,
            _symbol,
            _admin,
            _minter,
            _signer
        );
        _grantSignerRole(signerA.addr);
    }

    function test__deploy() public {
        assertEq(mentaportRegistry.name(), _name);
        assertEq(mentaportRegistry.symbol(), _symbol);
        assertEq(mentaportRegistry.totalProjects(), 0);
    }

    function test__pauseAndUnpauseRegistry() public {
        mentaportRegistry.pauseRegistry();
        mentaportRegistry.unpauseRegistry();
    }

    function testRevert__pauseAlreadyPausedRegistry() public {
        mentaportRegistry.pauseRegistry();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        mentaportRegistry.pauseRegistry();
    }

    function testRevert__unpauseAlreadyUnpausedRegistry() public {
        vm.expectRevert(Pausable.ExpectedPause.selector);
        mentaportRegistry.unpauseRegistry();
    }

    function testRevert__pauseRegistryWhenSenderIsNotOwner() public {
        bytes32 defaultAdminRole = mentaportRegistry.DEFAULT_ADMIN_ROLE();

        vm.prank(_signer);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _signer, defaultAdminRole)
        );
        mentaportRegistry.pauseRegistry();
    }

    function testRevert__unpauseRegistryWhenSenderIsNotOwner() public {
        mentaportRegistry.pauseRegistry();

        bytes32 defaultAdminRole = mentaportRegistry.DEFAULT_ADMIN_ROLE();

        vm.prank(_signer);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _signer, defaultAdminRole)
        );
        mentaportRegistry.unpauseRegistry();
    }

    ////////////////////////////////// Projects Functionality Section //////////////////////////////
    ///// 1. add project
    ///// 2. pause/unpause project
    ///// 3. pause/unpause project when already pause/unpaused. 
    ///// 4. update all variables of project when paused
    ///// 5. update all variables of project when not paused
    ///// 6. test valid update using specific updateProjectBaseURI function
    ///// 7. test valid update using specific updateMaxSupply function
    ///// 8. test valid update using specific updateProjectOwner function
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function test__addProjectWhenSenderIsOwnerAndRegistryIsNotPaused() public {
        uint128 expectedProjectId = mentaportRegistry.totalProjects();
        uint128 newProjectId = mentaportRegistry.addProject(projectRequest);
        assertEq(newProjectId, expectedProjectId);
        
        Project memory project = mentaportRegistry.getProject(expectedProjectId);

        assertEq(project.owner, projectOwner1.addr);
        assertEq(project.totalMinted, 0);
        assertEq(project.projectName, projectRequest.projectName);
        assertEq(project.id, expectedProjectId);
        assertEq(project.maxSupply, projectRequest.maxSupply);
        assertEq(project.projectBaseURI, projectRequest.projectBaseURI);
    }

    function test__pauseAndUnpauseProject() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);
        Project memory project = mentaportRegistry.getProject(projectId);
        assertEq(project.paused, true);

        vm.prank(_admin);
        mentaportRegistry.unpauseProject(projectId);
        project = mentaportRegistry.getProject(projectId);
        assertEq(project.paused, false);
    }

    function testRevert__pauseAlreadyPausedProject() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.pauseProject(projectId);
    }

    function testRevert__unpauseAlreadyUnpausedProject() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsUnpaused.selector, projectId)
        );
        mentaportRegistry.unpauseProject(projectId);
    }

    function test__updateAllProjectParameters() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();
        
        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "New Project Name",
            ownerName: "new owner",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.prank(_admin);
        mentaportRegistry.updateProject(projectId, updateProjectRequest);

        Project memory project = mentaportRegistry.getProject(projectId);
        assertEq(project.maxSupply, updateProjectRequest.maxSupply);
        assertEq(project.projectBaseURI, updateProjectRequest.projectBaseURI);
        assertEq(project.projectName, updateProjectRequest.projectName);
        assertEq(project.ownerName, updateProjectRequest.ownerName);
    }

    function test__updateProjectBaseURI() public {
        string memory newProjectUri = "https://newProjectBase.uri/";
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.updateProjectBaseURI(projectId, newProjectUri);

        Project memory project = mentaportRegistry.getProject(projectId);
        assertEq(project.projectBaseURI, newProjectUri);
    }

    function test__updateProjectMaxSupply() public {
        uint128 newMaxSupply = 5;
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.updateProjectMaxSupply(projectId, newMaxSupply);

        Project memory project = mentaportRegistry.getProject(projectId);
        assertEq(project.maxSupply, newMaxSupply);
    }

    function test__updateProjectOwner() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.updateProjectOwner(projectId, notProjectOwner, "New Owner");

        Project memory project = mentaportRegistry.getProject(projectId);
        assertEq(project.owner, notProjectOwner);
        assertEq(project.ownerName, "New Owner");
    }

    function testRevert__updateAllProjectParametersWhenProjectPaused() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();
        
        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "New Project Name",
            ownerName: "New Owner Name",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectBaseURIWhenProjectPaused() public {
        string memory newProjectUri = "https://newProjectBase.uri/";
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectBaseURI(projectId, newProjectUri);
    }

    function testRevert__updateProjectMaxSupplyWhenProjectPaused() public {
        uint128 newMaxSupply = 5;
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectMaxSupply(projectId, newMaxSupply);
    }

    function testRevert__updateProjectOwnerWhenProjectPaused() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.prank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectOwner(projectId, notProjectOwner, "New Owner");
    }

    ////////////////////// Failed Add Project Transaction Revert Section ////////////////////////////
    ///// 1. Revert if add project with no admin role
    ///// 2. Revert if add Project When Registry Is Paused
    ///// 3. Revert if add Project When Zero Address For Owner. 
    ///// 4. Revert if add Project When Name is Empty string
    ///// 5. Revert if add Project When ProjectBaseURI is Empty string
    ///// 6. Revert if add Project With Zero Max Supply
    ///// 7. Fuzz test for add project with different values that shouldn't revert
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testRevert__addProjectWhenSenderHasNoContractAdminRole() public {
        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();

        vm.prank(_signer);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _signer, contractAdminRole)
        );
        mentaportRegistry.addProject(projectRequest);
    }

    function testRevert__addProjectWhenRegistryIsPaused() public {
        mentaportRegistry.pauseRegistry();
        vm.expectRevert(Pausable.EnforcedPause.selector);

        mentaportRegistry.addProject(projectRequest);
    }

    function testRevert__addProjectWhenZeroOwnerAddress() public {
        projectRequest.owner = address(0);
        vm.expectRevert(MentaportCertificateRegisteryErrors.ZeroAddressUsed.selector);

        mentaportRegistry.addProject(projectRequest);
    }

    function testRevert__addProjectWhenNameIsEmpty() public {
        projectRequest.projectName = "";
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);

        mentaportRegistry.addProject(projectRequest);
    }

    function testRevert__addProjectWhenProjectBaseURIIsEmpty() public {
        projectRequest.projectBaseURI = '';
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);

        mentaportRegistry.addProject(projectRequest);
    }

    function testRevert__addProjectWithZeroMaxSupply() public {
        ProjectRequest memory _projectRequest = projectRequest;
        _projectRequest.maxSupply = 0;

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ZeroValueUsed.selector)
        );
        mentaportRegistry.addProject(_projectRequest);
    }

    function testFuzzing__addProject(
        uint128 maxSupply, 
        address owner,
        string memory ownerName, 
        string memory projectName, 
        string memory projectBaseURI
    ) public {
        uint128 expectedProjectId = mentaportRegistry.totalProjects();
        // Avoid specific values for fuzz testing
        vm.assume(maxSupply != 0);
        vm.assume(owner != address(0));
        vm.assume(keccak256(abi.encodePacked(ownerName)) != keccak256(abi.encodePacked("")));
        vm.assume(keccak256(abi.encodePacked(projectName)) != keccak256(abi.encodePacked("")));
        vm.assume(keccak256(abi.encodePacked(projectBaseURI)) != keccak256(abi.encodePacked("")));

        // Create a dummy ProjectRequest with fuzzed parameters
        ProjectRequest memory projectRequest1 = ProjectRequest({
            maxSupply: maxSupply,
            owner: owner,
            ownerName: ownerName,
            projectName: projectName,
            projectBaseURI: projectBaseURI
        });

        // Call addProject with the fuzzed ProjectRequest
        // Check the contract's response and state changes
        mentaportRegistry.addProject(projectRequest1);

        Project memory project = mentaportRegistry.getProject(expectedProjectId);

        // Assertions go here
        assertEq(project.owner, owner);
        assertEq(project.totalMinted, 0);
        assertEq(project.ownerName, ownerName);
        assertEq(project.projectName, projectName);
        assertEq(project.id, expectedProjectId);
        assertEq(project.maxSupply, maxSupply);
        assertEq(project.projectBaseURI, projectBaseURI);
    }

    ///////////////////// Failed Update Project Transactions Revert Section /////////////////////////
    ///// 1. Revert if updateProject When Not Project Owner
    ///// 2. Revert if updateProject When Not Project Is Paused
    ///// 3. Revert if updateProject With Zero MaxSupply
    ///// 4. Revert if updateProject When New Owner Zero Address
    ///// 5. Revert if updateProject When Name Is Empty String
    ///// 6. Revert if updateProject When ProjectURI Is Empty String
    ///// 7. Revert if updateProject When MaxSupply Below TotalSupply. 
    ///// 8. Revert if updateProject When Using Id for Non Existing Project
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testRevert__updateProjectWhenNotProjectOwner() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();
        vm.prank(notProjectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, notProjectOwner, contractAdminRole)
        );
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWhenNotProjectIsPaused() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.startPrank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWithZeroMaxSupply() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 0,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.expectRevert(MentaportCertificateRegisteryErrors.ZeroValueUsed.selector);
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWhenProjectNameIsEmptyString() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "",
            ownerName: "New Owner",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.startPrank(_admin);
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWhenOwnerNameIsEmptyString() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "New Project",
            ownerName: "",
            maxSupply: 20,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.startPrank(_admin);
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWhenProjectURIIsEmptyString() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 20,
            projectBaseURI: ""
        });

        vm.startPrank(_admin);
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectWhenMaxSupplyBelowTotalSupply() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp1 = block.timestamp;
        MintRequest memory mintRequest1 = _createMintRequest(timestamp1, "1");
        
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest1);

        uint timestamp2 = block.timestamp;
        MintRequest memory mintRequest2 = _createMintRequest(timestamp2, "2");
        
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest2);

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 1,
            projectBaseURI: "https://newprojecturi.com/"
        });

        vm.startPrank(_admin);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.InvalidProjectMaxSupply.selector, projectId, 1 , 2)
        );
        mentaportRegistry.updateProject(projectId, updateProjectRequest);
    }

    function testRevert__updateProjectNonExistingProject() public {
        _addProjects();

        UpdtateProjectRequest memory updateProjectRequest = UpdtateProjectRequest({
            projectName: "NewName",
            ownerName: "New Owner",
            maxSupply: 10,
            projectBaseURI: "https://newprojecturi.com/"
        });

        uint128 nonExistingProjectId = mentaportRegistry.totalProjects() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonExistingProject.selector, nonExistingProjectId)
        );
        mentaportRegistry.updateProject(nonExistingProjectId, updateProjectRequest);
    }

    ////////////// Failed Update Project Using Specifc Update Functions Revert Section //////////////
    ///// 1. Revert if updateProjectMaxSupply When Not Project Owner
    ///// 2. Revert if updateProjectMaxSupply When Project Is Paused
    ///// 3. Revert if updateProjectMaxSupply With Zero MaxSupply
    ///// 4. Revert if updateProjectMaxSupply With Less Than Total Minted
    ///// 5. Revert if updateProjectMaxSupply With Non Existing Project
    ///// 6. Revert if updateProjectOwner When Not Project Owner
    ///// 7. Revert if updateProjectOwner When Project Is Paused
    ///// 8. Revert if updateProjectOwner With Zero Owner Address
    ///// 9. Revert if updateProjectOwner When Already Project Owner
    ///// 10. Revert if updateProjectOwner With Non Existing Project
    ///// 11. Revert if updateProjectBaseURI When Not Project Owner
    ///// 12. Revert if updateProjectBaseURI When Project Is Paused
    ///// 13. Revert if updateProjectBaseURI With Empty String ProjectURI
    ///// 14. Revert if updateProjectBaseURI With Non Existing Project
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testRevert__updateProjectMaxSupplyWhenNotProjectOwner() public {
        uint128 newMaxSupply = 5;
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();
        vm.prank(notProjectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, notProjectOwner, contractAdminRole)
        );
        mentaportRegistry.updateProjectMaxSupply(projectId, newMaxSupply);
    }

    function testRevert__updateProjectMaxSupplyWhenProjectIsPaused() public {
        uint128 newMaxSupply = 5;
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.startPrank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectMaxSupply(projectId, newMaxSupply);
    }

    function testRevert__updateProjectMaxSupplyWithZeroValue() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.expectRevert(MentaportCertificateRegisteryErrors.ZeroValueUsed.selector);
        mentaportRegistry.updateProjectMaxSupply(projectId, 0);
    }

    function testRevert__updateProjectMaxSupplyLessThanTotalMinted() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp1 = block.timestamp;
        MintRequest memory mintRequest1 = _createMintRequest(timestamp1, "1");
        
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest1);

        uint timestamp2 = block.timestamp;
        MintRequest memory mintRequest2 = _createMintRequest(timestamp2, "2");
        
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest2);

        vm.prank(_admin);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.InvalidProjectMaxSupply.selector, projectId, 1, 2)
        );
        mentaportRegistry.updateProjectMaxSupply(projectId, 1);
    }

    function testRevert__updateProjectMaxSupplyrNonExistingProject() public {
        _addProjects();

        uint128 nonExistingProjectId = mentaportRegistry.totalProjects() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonExistingProject.selector, nonExistingProjectId)
        );
        mentaportRegistry.updateProjectMaxSupply(nonExistingProjectId, 3);
    }

    function testRevert__updateProjectOwnerWhenNotProjectOwner() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();
        vm.prank(notProjectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, notProjectOwner, contractAdminRole)
        );
        mentaportRegistry.updateProjectOwner(projectId, notProjectOwner, "New Owner");
    }

    function testRevert__updateProjectOwnerWhenProjectIsPaused() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.startPrank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectOwner(projectId, notProjectOwner, "New Owner");
    }

    function testRevert__updateProjectOwnerWithZeroAddress() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.expectRevert(MentaportCertificateRegisteryErrors.ZeroAddressUsed.selector);
        mentaportRegistry.updateProjectOwner(projectId, address(0), "New Owner");
    }

    function testRevert__updateProjectOwnerWhenAlreadyProjectOwner() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.startPrank(_admin);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.AlreadyProjectOwner.selector, projectId, projectOwner1.addr)
        );
        mentaportRegistry.updateProjectOwner(projectId, projectOwner1.addr, "New Owner");
    }

    function testRevert__updateProjectOwnerNonExistingProject() public {
        _addProjects();

        uint128 nonExistingProjectId = mentaportRegistry.totalProjects() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonExistingProject.selector, nonExistingProjectId)
        );
        mentaportRegistry.updateProjectOwner(nonExistingProjectId, notProjectOwner, "New Owner");
    }

    function testRevert__updateProjectBaseURIWithNotProjectOwner() public {
        string memory newProjectUri = 'https://newProjectBase.uri/';
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();
        vm.prank(notProjectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, notProjectOwner, contractAdminRole)
        );
        mentaportRegistry.updateProjectBaseURI(projectId, newProjectUri);
    }

    function testRevert__updateProjectBaseURIWhenProjectIsPaused() public {
        string memory newProjectUri = 'https://newProjectBase.uri/';
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.startPrank(_admin);
        mentaportRegistry.pauseProject(projectId);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.updateProjectBaseURI(projectId, newProjectUri);
    }

    function testRevert__updateProjectBaseURIWhenProjectURIIsEmptyString() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        vm.startPrank(_admin);
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);
        mentaportRegistry.updateProjectBaseURI(projectId, "");
    }

    function testRevert__updateProjectBaseURIrNonExistingProject() public {
        _addProjects();
        string memory newProjectUri = "https://newProjectBase.uri/";
        uint128 nonExistingProjectId = mentaportRegistry.totalProjects() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonExistingProject.selector, nonExistingProjectId)
        );
        mentaportRegistry.updateProjectBaseURI(nonExistingProjectId, newProjectUri);
    }

    ////////////// Testing Mint Certificate for success and failed scenarios //////////////
    ///// 1. Success in mintCertificate with right role and right parameters
    ///// 2. Success in mintCertificate After Pausing and then Unpausing
    ///// 3. Revert if mintCertificate When Registry Is Paused
    ///// 4. Revert if mintCertificate With Non Existing Project
    ///// 5. Revert if mintCertificate When Project MaxSupply Exceeded
    ///// 6. Revert if mintCertificate By Non Minter Role
    ///// 7. Revert if mintCertificate When Project Is Paused
    ///// 8. Revert if mintCertificate With Zero Owner Address
    ///// 9. Revert if mintCertificate When Already Project Owner
    ///// 10. Revert if mintCertificate With Non Existing Project
    ///// 11. Revert if mintCertificate When Not Project Owner
    ///// 12. Revert if mintCertificate When Project Is Paused
    ///// 13. Revert if mintCertificate With Empty String ProjectURI
    ///// 14. Revert if mintCertificate With Non Existing Project
    ///////////////////////////////////////////////////////////////////////////////////////////////////


    function test__mintCertificate() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.prank(_minter);
        uint256 tokenId = mentaportRegistry.mintCertificate(projectId, mintRequest);
        assertEq(tokenId, uint256(1));

        Certificate memory cert = mentaportRegistry.getCertificate(mintRequest.certificateId);

        assertEq(cert.tokenId, tokenId);
        assertEq(cert.c2paManifestURI, mintRequest.c2paManifestURI);
        assertEq(cert.tokenURI, mintRequest.tokenURI);
    }

    function test__mintCertificateAfterPauseUnpausProject() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");
        vm.startPrank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);

        vm.startPrank(_admin);
        mentaportRegistry.pauseProject(projectId);

        vm.startPrank(_minter);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectIsPaused.selector, projectId)
        );
        mentaportRegistry.mintCertificate(projectId, mintRequest);

        vm.startPrank(_admin);
        mentaportRegistry.unpauseProject(projectId);

        vm.startPrank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);

    }

    function testRevert__mintCertificateWhenRegistryIsPaused() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();
        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        mentaportRegistry.pauseRegistry();
        vm.prank(_minter);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        mentaportRegistry.mintCertificate(projectId, mintRequest);
    }

    function testRevert__mintCertificateForNonExistingProject() public {
        _addProjects();
        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        uint128 nonExistingProjectId = mentaportRegistry.totalProjects() + 1;
        
        vm.prank(_minter);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonExistingProject.selector, nonExistingProjectId)
        );
        mentaportRegistry.mintCertificate(nonExistingProjectId, mintRequest);
    }  

    function testRevert__mintCertificateWhenProjectMaxSupplyExceeded() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();
        uint timestamp1 = block.timestamp;
        MintRequest memory mintRequest1 = _createMintRequest(timestamp1, "1");
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest1);

        vm.prank(_admin);
        mentaportRegistry.updateProjectMaxSupply(projectId, 1);

        uint timestamp2 = block.timestamp;
        MintRequest memory mintRequest2 = _createMintRequest(timestamp2, "2");
        
        vm.prank(_minter);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.ProjectMaxSupplyExceeded.selector, projectId, 1, 1)
        );
        mentaportRegistry.mintCertificate(projectId, mintRequest2);
    }

    function testRevert__mintCertificateByNonMinterRole() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        bytes32 minterRole = mentaportRegistry.MINTER_ROLE();

        vm.prank(signerA.addr);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, signerA.addr, minterRole)
        );
         mentaportRegistry.mintCertificate(projectId, mintRequest);
    }

    ////////////// Testing Mint Certificate for success and failed scenarios //////////////
    ///// 1. Success in updateTokenUri with right role and right parameters
    ///// 2. Revert if updateTokenUri With TokenUri as Empty String
    ///// 3. Revert if updateTokenUri With Non Existing Token Id
    ///// 4. Revert if updateTokenUri When Caller is not Contract Admin
    ///////////////////////////////////////////////////////////////////////////////////////

    function test__updateTokenUriWhenCallerIsProjectOwner() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.recordLogs();
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 tokenId = uint(entries[2].topics[1]);
        string memory newTokenUri = "https://newtokenuri.com";

        vm.prank(_admin);
        mentaportRegistry.updateTokenUri(tokenId, newTokenUri);
        assertEq(mentaportRegistry.tokenURI(tokenId), newTokenUri);

        Certificate memory cert = mentaportRegistry.getCertificate(mintRequest.certificateId);
        assertEq(cert.tokenURI, newTokenUri);
    }

    function testRevert__failToUpdateTokenUriWithEmptyUri() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);

        vm.prank(_admin);
        vm.expectRevert(MentaportCertificateRegisteryErrors.EmptyStringUsed.selector);
        mentaportRegistry.updateTokenUri(1, "");
    }

    function testRevert__failToUpdateTokenUriForNonExistingTokenId() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);

        vm.prank(_admin);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 2)
        );
        mentaportRegistry.updateTokenUri(2, "https://newtoken.uri/2");
    }

    function testRevert__failToUpdateTokenUriWhenCallerIsNotContractAdmin() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.recordLogs();
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 tokenId = uint(entries[2].topics[1]);

        string memory newTokenUri = "https://newtokenuri.com";

        bytes32 contractAdminRole = mentaportRegistry.CONTRACT_ADMIN();
        vm.prank(notProjectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, notProjectOwner, contractAdminRole)
        );
        mentaportRegistry.updateTokenUri(tokenId, newTokenUri);
    }

    ////////////// Testing Getters and Other Utils //////////////
    ///// 1. Success in validate signature of approved signer and return True
    ///// 2. Success in validate signature of non approved signer and return False
    ///// 3. Success in getProjectTotalMints returning the right value of total mints per project
    ///// 4. Success in fetching the correct ProjectId From a TokenId
    ///// 5. Success in testing the right supported interfaces IERC165, IERC721, IERC721 Metadata, IERC4906, Access Control
    ///// 6. Success in testing sending ETH/MATIC to contract and withdraw with correct role and parameter and fail if not authorized or wrong parameter
    ///////////////////////////////////////////////////////////////////////////////////////

    function test__assertValidReturnIsValidSignatureForApprovedSigner() public {
        _addProjects();

        uint timestamp = block.timestamp;
        bytes memory signature = _generateSignature(signerA, address(mentaportRegistry), signerA.addr, timestamp, block.chainid);

        bool isValidSignature = mentaportRegistry.isValidSigner(signerA.addr, timestamp, signature);
        assertEq(isValidSignature, true);
    }

    function testRevert__inValidSignatureForNonApprovedSigner() public {
        _addProjects();

        uint timestamp = block.timestamp;
        bytes memory signature = _generateSignature(InvalidSigner, address(mentaportRegistry), InvalidSigner.addr, timestamp, block.chainid);

        vm.expectRevert(MentaportCertificateRegisteryErrors.InvalidSignature.selector);
        bool isValidSignature = mentaportRegistry.isValidSigner(InvalidSigner.addr, timestamp, signature);
    }

    function test__getProjectTotalMints() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();
    
        uint timestamp1 = block.timestamp;
        MintRequest memory mintRequest1 = _createMintRequest(timestamp1, "1");

        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest1);

        uint timestamp2 = block.timestamp;
        MintRequest memory mintRequest2 = _createMintRequest(timestamp2, "2");

        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest2);

        assertEq(mentaportRegistry.getProjectTotalMints(projectId),2);
    }

    function test__fetchProjectIdFromTokenId() public {
        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.recordLogs();
        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 tokenId = entries[2].topics[1];
        assertEq(mentaportRegistry.getProjectIdFromTokenId(uint(tokenId)), projectId);
    }

    function testSupportsIERC165Interface() public {
        assertTrue(mentaportRegistry.supportsInterface(0x01ffc9a7));
    }

    function testSupportsERC721Interface() public {
        assertTrue(mentaportRegistry.supportsInterface(0x80ac58cd));
    }

    function testSupportsMetadataInterface() public {
        assertTrue(mentaportRegistry.supportsInterface(0x5b5e139f));
    }

    function testSupportsAccessConrolInterface() public {
        assertTrue(mentaportRegistry.supportsInterface(0x7965db0b));
    }

    function testSupportsIERC4906Interface() public {
        assertTrue(mentaportRegistry.supportsInterface(0x49064906));
    }

    function test_SendEthToContractAndWithdraw() public {
        address fundingAccount = makeAddr('fundingAccount');
        address receiverAccount = makeAddr('receiverAccount');

        uint256 amount = 1 ether;
        vm.deal(fundingAccount, amount);

        // Assert initial balance
        assertEq(address(mentaportRegistry).balance, 0);
        
        // Sending ETH from fundingAccount to the contract
        vm.prank(fundingAccount);
        (bool success, ) = address(mentaportRegistry).call{value: amount}("");

        assertTrue(success);
        assertEq(address(mentaportRegistry).balance, amount);

        bytes32 mentaportRole = mentaportRegistry.DEFAULT_ADMIN_ROLE();

        // Expect fail to withdraw if non owner tried to withdraw
        vm.prank(signerA.addr);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, signerA.addr, mentaportRole)
        );
        mentaportRegistry.withdraw(receiverAccount);

        // Expect to fail if sending to Zero Address
        vm.expectRevert(MentaportCertificateRegisteryErrors.ZeroAddressUsed.selector);
        mentaportRegistry.withdraw(address(0));

        vm.deal(receiverAccount, 0);
        // Assert that owner can withdraw funds to mentaportAccount
        mentaportRegistry.withdraw(receiverAccount);
        assertEq(address(receiverAccount).balance, amount);
        assertEq(address(mentaportRegistry).balance, 0);

        // Expect fail to withdraw since contract balance is zero
        vm.expectRevert(MentaportCertificateRegisteryErrors.InsufficientBalance.selector);
        mentaportRegistry.withdraw(receiverAccount);
    }

    // /*//////////////////////////////////////////////////////////////
    //                            HELPERS
    // //////////////////////////////////////////////////////////////*/
    function _addProjects() internal {
        mentaportRegistry.addProject(projectRequest);
        ProjectRequest memory _projectRequest = projectRequest;
        _projectRequest.owner = projectOwner2.addr;
        mentaportRegistry.addProject(_projectRequest);
    }

    function _grantSignerRole(address signer) internal {
        bytes32 signerRole = mentaportRegistry.SIGNER_ROLE();
        vm.startPrank(_admin);
        mentaportRegistry.grantRole(signerRole, signer);
        vm.stopPrank();
    }

    function _generateSignature(
        Account memory signer,
        address contractAddress,
        address receiver,
        uint256 timestamp,
        uint256 chainId
    ) internal pure returns(bytes memory signature) {
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256("Mentaport-Certificate"),
                keccak256("1"),
                chainId,
                contractAddress
            )
        );

        bytes32 TYPEHASH = keccak256("MintMessage(address receiver,uint256 timestamp)");
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                receiver,
                timestamp
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.key, digest);
        signature = abi.encodePacked(r, s, v);

    }

    function _createMintRequest(
        uint timestamp,
        string memory certificateId
    ) internal view returns(MintRequest memory) {
        return MintRequest({
            timestamp: timestamp,
            tokenURI: projectUri,
            certificateId: certificateId,
            c2paManifestURI: c2paManifestURI
        });
    }
}
