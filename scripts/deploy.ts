import {ethers} from "@nomiclabs/buidler";

async function main() {
  const factory = await ethers.getContractFactory("ERC20FlashTest");

  // If we had constructor arguments, they would be passed into deploy()
  let contract = await factory.deploy("0x31d680f9B98899925B19C9455423527d3AC36172");

  // The address the Contract WILL have once mined
  console.log(contract.address);

  // The transaction that was sent to the network to deploy the Contract
  console.log(contract.deployTransaction.hash);

  // The contract is NOT deployed yet; we must wait until it is mined
  await contract.deployed();
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
