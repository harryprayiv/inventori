export const readFileImpl = file => callback => () => {
  const reader = new FileReader();
  reader.onload = async e => {
    const text = e.target.result;
    const buf  = await new Blob([text]).arrayBuffer();
    const hashBuf = await crypto.subtle.digest("SHA-256", buf);
    const hash = Array.from(new Uint8Array(hashBuf))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");
    callback({ content: text, hash })();
  };
  reader.readAsText(file);
  return () => {};  // canceller (no-op)
};

export const downloadStringImpl = filename => mimeType => content => () => {
  const blob = new Blob([content], { type: mimeType });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement("a");
  a.href     = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => {
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, 100);
};

export const showErrorOverlayImpl = () => {
  const overlay = document.createElement("div");
  overlay.id = "error-overlay";
  const gif = document.createElement("div");
  gif.className = "nedry-gif";
  overlay.appendChild(gif);
  document.body.appendChild(overlay);
  setTimeout(() => document.body.removeChild(overlay), 2000);
};