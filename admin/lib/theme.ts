export const THEME_STORAGE_KEY = "tk-admin-theme";

/**
 * Runs in <head> before first paint so a stored light/dark choice is applied
 * without a flash. Without a stored choice nothing is set and the CSS follows
 * prefers-color-scheme. Wrapped in try/catch because storage can throw
 * (private windows, blocked site data).
 */
export const THEME_INIT_SCRIPT = `try{var t=localStorage.getItem(${JSON.stringify(
  THEME_STORAGE_KEY
)});if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}`;
