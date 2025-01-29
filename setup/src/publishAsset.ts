import { normalizeSuiObjectId } from "@mysten/sui/utils";
import { Transaction } from "@mysten/sui/transactions";
import { fromHEX } from "@mysten/bcs";
import { getSigner } from "./helpers";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { CompiledModule, getBytecode } from "./utils/bytecode-template";
import init, * as wasm from "../../move-binary-format-wasm";
import { bytecode as genesis_bytecode } from "./utils/genesis_bytecode";


const client = new SuiClient({
  url: getFullnodeUrl('testnet'),
});

const publishNewAsset = async (
  moduleName: string,
  totalSupply: string,
  decimals: string,
  symbol: string,
  asset_name: string,
  description: string,
  iconUrl: string,
  mint_price: string,
  owner_owned_amount: string,
) => {
  const signer = getSigner();

  const template = getBytecode();

  const compiledModule = new CompiledModule(
    JSON.parse(wasm.deserialize(template))
  )
    .updateConstant(0, totalSupply, "100", "u64")
    .updateConstant(1, decimals, "9", "u8")
    .updateConstant(2, symbol, "Symbol", "string")
    .updateConstant(3, asset_name, "Name", "string")
    .updateConstant(4, description, "Description", "string")
    .updateConstant(5, iconUrl, "icon_url", "string")
    .updateConstant(6, mint_price, "1000", "u64")
    .updateConstant(7, owner_owned_amount, "10000", "u64")
   
    .changeIdentifiers({
      template: moduleName,
      TEMPLATE: moduleName.toUpperCase(),
    });


  const bytesToPublish = wasm.serialize(JSON.stringify(compiledModule));

  const tx = new Transaction();
  tx.setGasBudget(100000000);
  const [upgradeCap] = tx.publish({
    modules: [[...fromHEX(bytesToPublish)], [...fromHEX(genesis_bytecode)]],
    dependencies: [
      normalizeSuiObjectId("0x1"),
      normalizeSuiObjectId("0x2"),
    ],
  });

  tx.transferObjects(
    [upgradeCap],
    tx.pure("address", signer.getPublicKey().toSuiAddress())
  );

  const txRes = await client
    .signAndExecuteTransaction({
      transaction: tx,
      signer,
      requestType: "WaitForLocalExecution",
      options: {
        showEvents: true,
        showEffects: true,
        showObjectChanges: true,
        showBalanceChanges: true,
        showInput: true,
      },
    })
    .catch((e) => console.error(e)! || null);

  if (txRes?.effects?.status.status === "success") {
    // console.log("New asset published!", JSON.stringify(txRes, null, 2));
    console.log("New asset published! Digest:", txRes.digest);
  } else {
    console.log("Error: ", txRes?.effects?.status);
    throw new Error("Publishing failed");
  }
};

publishNewAsset(
  "joke_papa",
  "10000000000000000",
  "3",
  "JOKE",
  "Joke Evaluator",
  "A Joke Evaluator on Sui",
  "https://x.com/BobAndAliceSui",
  "1000000",
  "1000000000000"
);
