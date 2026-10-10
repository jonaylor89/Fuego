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
