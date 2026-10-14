// Click the brew command to copy it.
document.querySelectorAll("[data-copy]").forEach((button) => {
    const label = button.textContent;
    button.addEventListener("click", async () => {
        try {
            await navigator.clipboard.writeText(button.dataset.copy);
            button.textContent = "copied. paste it in your terminal.";
            button.classList.add("copied");
        } catch {
            return; // Clipboard unavailable; the command is still there to select.
        }
        setTimeout(() => {
            button.textContent = label;
            button.classList.remove("copied");
        }, 1800);
    });
});

// The download button stays disabled until there's a valid email. Submitting
// records it with hub (which sends a thank-you email) and starts the download.
const EMAIL_STORAGE_KEY = "download-gate-email";
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function rememberedEmail() {
    try {
        return localStorage.getItem(EMAIL_STORAGE_KEY) ?? "";
    } catch {
        return "";
    }
}

function rememberEmail(email) {
    try {
        localStorage.setItem(EMAIL_STORAGE_KEY, email);
    } catch {
        // Storage unavailable (private mode); they'll type it again next time.
    }
}

document.querySelectorAll("[data-download-form]").forEach((form) => {
    const email = form.querySelector(".email");
    const honeypot = form.querySelector(".hp");
    const button = form.querySelector("button[type=submit]");
    const isValid = () => email.checkValidity() && EMAIL_PATTERN.test(email.value.trim());
    const sync = () => {
        button.disabled = !isValid();
    };

    if (!email.value) email.value = rememberedEmail();
    sync();
    email.addEventListener("input", sync);
    // Browser autofill doesn't always fire "input".
    email.addEventListener("change", sync);

    form.addEventListener("submit", (event) => {
        event.preventDefault();
        if (!isValid()) return sync();

        const address = email.value.trim();
        rememberEmail(address);
        fetch(`${form.dataset.hubUrl}/api/downloads`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ app: form.dataset.app, email: address, website: honeypot.value }),
            keepalive: true,
        }).catch(() => {
            // Recording is best-effort; never block the download on it.
        });
        window.location.href = form.action;
    });
});
