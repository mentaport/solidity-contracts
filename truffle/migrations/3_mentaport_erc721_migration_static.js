const MentaportMintStatic = artifacts.require("MentaportMintStatic");
const MentaportDynamic = artifacts.require("MentaportDynamic");

const META_DATA_URL = "ipfs://bafkreifz7jvah7oakpwxcj4nicoa7ciysr5g23nzxql4hnqgwx5pcakd4y/metadata"

module.exports = function (deployer, network, accounts) {
  const admin = accounts[1];
  const minter= accounts[2];
  const signer = admin;

  deployer.deploy(MentaportMintStatic,'mentaportMintStatic','mentaportMintStatic','na',10, admin,minter, signer);
  deployer.deploy(MentaportDynamic,'mentaportDynamic','mentaportDynamic','na',10, admin,minter, signer);
};
