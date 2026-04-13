import { fromEffectFnAff, mkEffectFn1 } from "../output/Effect.Aff.Compat/index.js";

export const sha256HexImpl = text => callback => () => {
  const enc = new TextEncoder().encode(text);
  crypto.subtle.digest("SHA-256", enc).then(buf => {
    const hex = Array.from(new Uint8Array(buf))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");
    callback(hex)();
  });
  return () => {};  // canceller
};