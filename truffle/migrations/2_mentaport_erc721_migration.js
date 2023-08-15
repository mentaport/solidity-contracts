const MentaportERC721 = artifacts.require("MentaportERC721");
const MentaportMint = artifacts.require("MentaportMint");

const max_supply = 500

module.exports = function (deployer, network, accounts) {
    const owner = accounts[0];
    const admin = accounts[1];
    const minter= accounts[2];
    const signer = accounts[2];

    deployer.deploy(MentaportERC721,'mentaport','mentaport', max_supply, false, admin, minter, signer, owner);
    deployer.deploy(MentaportMint,'mentaport Mint','mentaportMint', max_supply, admin, minter, signer);
};
