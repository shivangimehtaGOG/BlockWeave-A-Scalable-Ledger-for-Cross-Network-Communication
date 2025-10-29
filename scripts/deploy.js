const hre = require("hardhat");

async function main() {
  // Get the contract factory
  const Project = await hre.ethers.getContractFactory("Project");

  // Deploy the contract
  const project = await Project.deploy();

  // Wait for deployment
  await project.waitForDeployment();

  console.log(`✅ BlockWeave contract deployed to: ${project.target}`);
}

// Run the deployment script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
