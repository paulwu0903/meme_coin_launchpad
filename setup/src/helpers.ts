import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { adminPhrase, SUI_NETWORK } from "./config";
import { getFullnodeUrl } from "@mysten/sui/client";

console.log("Connecting to", getFullnodeUrl('testnet'));

export function getSigner() {
  const keypair = Ed25519Keypair.fromSecretKey(process.env.PRIVATE_KEY!);

  const admin = keypair.getPublicKey().toSuiAddress();
  console.log("Admin Address = " + admin);

  return keypair;
}

getSigner();
