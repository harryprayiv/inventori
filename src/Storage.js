export const getItemImpl = nothing => just => key => () => {
  const val = localStorage.getItem(key);
  return val === null ? nothing : just(val);
};

export const setItemImpl = key => value => () => {
  localStorage.setItem(key, value);
};

export const removeItemImpl = key => () => {
  localStorage.removeItem(key);
};

export const reloadImpl = () => {
  window.location.reload();
};

// crypto.randomUUID() is vastly better than Math.random().toString(36)
export const generateUUIDImpl = () => {
  return crypto.randomUUID();
};