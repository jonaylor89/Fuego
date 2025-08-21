# 🔥 Fuego Website

The official website for Fuego - a minimal focus app for macOS.

## Overview

This is a static website built with vanilla HTML, CSS, and JavaScript. It showcases the Fuego app with:

- Clean, minimal design matching the app's aesthetic
- Responsive layout that works on all devices
- Interactive demo of the website blocking feature
- Stoic philosophy integration with rotating quotes
- Modern CSS with dark theme and subtle animations

## Local Development

Since this is a static site, you can run it locally with any static file server:

```bash
# Using Python (most systems have this)
cd website
python -m http.server 8000

# Using Node.js
npx serve .

# Using PHP (if installed)
php -S localhost:8000
```

Then open http://localhost:8000 in your browser.

## Deployment

The site is configured for multiple hosting platforms:

### Netlify (Recommended)
- Automatic deployments from GitHub
- CDN and SSL included
- Configuration in `netlify.toml`

### Vercel
- Edge network deployment
- Configuration in `vercel.json`

### GitHub Pages
- Free hosting for public repos
- Configuration in `.github/workflows/deploy.yml`

### Manual Deployment
Simply upload the contents of the `website` directory to any static hosting service.

## Customization

### Content Updates
- Edit `index.html` for content changes
- Modify `styles.css` for styling updates
- Update `script.js` for interactive features

### Brand Colors
Update CSS variables in `styles.css`:
```css
:root {
    --accent-orange: #ff6b35;
    --accent-blue: #667eea;
    --accent-purple: #764ba2;
}
```

### Download Links
Update download URLs in the HTML and consider implementing GitHub releases API integration in `script.js`.

## Features

- **Responsive Design**: Works perfectly on desktop, tablet, and mobile
- **Performance Optimized**: Minimal dependencies, optimized assets
- **SEO Ready**: Proper meta tags, Open Graph, and Twitter Cards
- **Accessibility**: Semantic HTML and proper contrast ratios
- **Modern CSS**: CSS Grid, Flexbox, custom properties
- **Progressive Enhancement**: Works without JavaScript
- **Easter Eggs**: Konami code and other interactive elements

## File Structure

```
website/
├── index.html          # Main page
├── styles.css          # All styles
├── script.js           # Interactive features
├── netlify.toml        # Netlify configuration
├── vercel.json         # Vercel configuration
├── .github/workflows/
│   └── deploy.yml      # GitHub Actions workflow
└── README.md           # This file
```

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- iOS Safari 14+
- Android Chrome 90+

## Performance

The website is optimized for performance:
- Zero external dependencies (except Google Fonts)
- Inline critical CSS
- Optimized images and assets
- Proper caching headers
- Minimal JavaScript

## Security

Security headers are configured for all hosting platforms:
- Content Security Policy
- X-Frame-Options
- X-XSS-Protection
- X-Content-Type-Options
- Referrer Policy

---

Built with 🔥 for focused productivity
