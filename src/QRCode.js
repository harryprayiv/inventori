// QRCode constructor is injected globally by the CDN script.
export const makeQRCodeImpl = el => url => width => height => () => {
  el.innerHTML = "";
  new QRCode(el, { text: url, width, height });
};