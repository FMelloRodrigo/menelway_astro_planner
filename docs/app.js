/**
 * MENELWAY — Open Source Astronomy Tools
 * Lightweight client script: Theme toggle and FAQ accordions
 */

document.addEventListener('DOMContentLoaded', () => {
  // Theme Management
  const theme = localStorage.getItem('menelway_theme') || 'obsidian';
  applyTheme(theme);

  const themeBtn = document.getElementById('themeToggleBtn');
  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') === 'red' ? 'red' : 'obsidian';
      const next = current === 'obsidian' ? 'red' : 'obsidian';
      applyTheme(next);
      localStorage.setItem('menelway_theme', next);
    });
  }

  // FAQ Accordion
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    if (question) {
      question.addEventListener('click', () => {
        const isOpen = item.classList.contains('open');
        faqItems.forEach(i => i.classList.remove('open'));
        if (!isOpen) item.classList.add('open');
      });
    }
  });
});

function applyTheme(theme) {
  const root = document.documentElement;
  const themeLabel = document.getElementById('themeBtnLabel');
  const themeIcon = document.getElementById('themeBtnIcon');

  if (theme === 'red') {
    root.setAttribute('data-theme', 'red');
    if (themeLabel) themeLabel.textContent = 'Normal';
    if (themeIcon) themeIcon.textContent = '🌙';
  } else {
    root.removeAttribute('data-theme');
    if (themeLabel) themeLabel.textContent = 'Night Vision';
    if (themeIcon) themeIcon.textContent = '🔴';
  }
}
