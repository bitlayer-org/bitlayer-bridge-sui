import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { bcs, fromHex, toHex } from '@mysten/bcs';

async function main() {
  const suiClient = new SuiClient({ url: getFullnodeUrl('mainnet') });
  const tx = new Transaction();
  // inputs
  const targetChain = 1; // u8
  const targetTokenId = 1; // u8

  // multisig / sender address
  const sender = '';
  if (!sender) throw new Error('Missing MULTISIG_ADDRESS');

  const tokenObjectId = '';
  if (!tokenObjectId) throw new Error('Missing TOKEN_OBJECT_ID');

  // EVM address must be 20 bytes
  const evmAddress = '';
  if (!evmAddress) throw new Error('Missing EVM_USER_ADDRESS');
  
  const evmBytes = fromHex(evmAddress);
  if (evmBytes.length !== 20) throw new Error(`EVM_USER_ADDRESS must be 20 bytes, got ${evmBytes.length}`);
  tx.moveCall({
    target: `0xe335b55f72da08ccc3685be358f48e8b11b4503bfe7b1d9a7cbe0fb6aabb9595::bridge::send_token`,
    typeArguments: ['0xa03ab7eee2c8e97111977b77374eaf6324ba617e7027382228350db08469189e::ybtc::YBTC'],
    arguments: [
      tx.object('0x54739f73cc2ea056e043571b22f84b0c896b7c4c2741f7824b7b66fbf2e1ece3'),
      tx.pure.u8(targetChain),
      tx.pure.u8(targetTokenId),
      bcs.vector(bcs.u8()).serialize(evmBytes),
      tx.object(tokenObjectId),
    ],
  });
  tx.setSender(sender);
  const txBytes = await tx.build({ client: suiClient });
  console.log(toHex(txBytes));
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});