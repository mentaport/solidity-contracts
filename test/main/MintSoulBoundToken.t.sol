//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {
    Project,
    MintRequest,
    ProjectRequest,
    MentaportCertificateRegistry
} from "../../src/main/MentaportCertificateRegistry.sol";
import "../../src/interfaces/errors.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract MintSoulBoundTokenTest is Test {
    using ECDSA for bytes32;

    string public constant _name = "MentaportCertificateRegistry";
    string public constant _symbol = "MER";
    uint256 public constant _maxSupply = 1000;
    //makeAddr creates an address derived from the provided name.
    address public _admin = makeAddr("admin");
    address public _minter = makeAddr("minter");
    address public _signer = makeAddr("signer");
    address public _newAccount = makeAddr("newAccount");
    address public notProjectOwner = makeAddr("notProjectOwner");

    //makeAccount: creates a struct containing both a labeled address and the corresponding private key
    Account public signerA = makeAccount("signerA");
    Account public signerB = makeAccount("signerB");
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

    function testRevert__FailToTransferSoulBoundToken() public {

        uint128 projectId = mentaportRegistry.totalProjects();
        _addProjects();

        uint timestamp = block.timestamp;
        MintRequest memory mintRequest = _createMintRequest(timestamp, "1");

        vm.prank(_minter);
        mentaportRegistry.mintCertificate(projectId, mintRequest);

        vm.prank(signerA.addr);
        vm.expectRevert(
            abi.encodeWithSelector(MentaportCertificateRegisteryErrors.NonTransferableToken.selector, 1)
        );
        mentaportRegistry.transferFrom(signerA.addr, signerB.addr, 1);
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
        uint256 timestamp
    ) internal view returns(bytes memory signature) {
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256("Mentaport-Certificate"),
                keccak256("1"),
                block.chainid,
                contractAddress
            )
        );

        bytes32 TYPEHASH = keccak256("MintMessage(address receiver,uint256 timestamp)");
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                signer.addr,
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
