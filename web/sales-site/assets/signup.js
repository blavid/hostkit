/* signup.html: mock trial form. Runs after site.js, which has already read ?code=. */
import { validateSignup, buildTrialRecord, saveTrial, wizardHref, normalizeCode, CODE_KEY } from "./trial.js";

const form = document.getElementById("trial-form");
const code = normalizeCode(window.HOSTKIT_CODE || "");
const fields = { name: document.getElementById("t-name"), email: document.getElementById("t-email") };

function showErrors(errors) {
  for (const key of Object.keys(fields)) {
    const input = fields[key];
    const msg = document.getElementById(`${input.id}-err`);
    const err = errors[key] || "";
    msg.textContent = err;
    if (err) input.setAttribute("aria-invalid", "true");
    else input.removeAttribute("aria-invalid");
  }
}

form.addEventListener("submit", (ev) => {
  ev.preventDefault();
  const data = { name: fields.name.value, email: fields.email.value, code };
  const result = validateSignup(data);
  showErrors(result.errors);
  if (!result.ok) {
    (result.errors.name ? fields.name : fields.email).focus();
    return;
  }
  saveTrial(window.localStorage, buildTrialRecord(data));
  if (code) { try { window.sessionStorage.setItem(CODE_KEY, code); } catch {} }
  window.location.assign(wizardHref(code));
});
