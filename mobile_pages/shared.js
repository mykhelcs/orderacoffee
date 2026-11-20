(function () {
  function applySavedTheme() {
    const screen = document.getElementById('phoneScreen');
    if (!screen) return;
    if (screen.dataset.forceTheme === 'auth' || screen.dataset.forceTheme === 'splash') return;
    const isDark = localStorage.getItem('cafego_theme') === 'dark';
    screen.classList.toggle('dark-mode', isDark);
    const label = document.getElementById('themeToggleLabel');
    const icon = document.getElementById('themeToggleIcon');
    if (label && icon) {
      if (isDark) {
        icon.textContent = '☀️';
        label.textContent = 'Light';
      } else {
        icon.textContent = '🌙';
        label.textContent = 'Espresso';
      }
    }
  }

  window.toggleAppTheme = function () {
    const screen = document.getElementById('phoneScreen');
    if (!screen) return;
    const nextDark = !screen.classList.contains('dark-mode');
    localStorage.setItem('cafego_theme', nextDark ? 'dark' : 'light');
    applySavedTheme();
  };

  window.addEventListener('DOMContentLoaded', applySavedTheme);
})();
