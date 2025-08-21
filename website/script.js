// Minimal interactions for simple Fuego website

document.addEventListener('DOMContentLoaded', function() {
    // Add smooth scrolling for anchor links  
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
    
    // Simple easter egg - make the flame emoji bigger on triple click
    let clickCount = 0;
    const titleElement = document.querySelector('h1');
    
    if (titleElement) {
        titleElement.addEventListener('click', function() {
            clickCount++;
            if (clickCount === 3) {
                this.innerHTML = this.innerHTML.replace('🔥', '<span style="font-size: 1.5em;">🔥</span>');
                clickCount = 0; // Reset
            }
        });
    }
});
