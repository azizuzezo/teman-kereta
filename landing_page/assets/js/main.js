// Teman Kereta Landing Page Interactive JS

function handleImageFallback(imgElement) {
  const currentSrc = imgElement.src;
  const pngSrc = imgElement.getAttribute('data-png');
  const fallbackSvg = imgElement.getAttribute('data-fallback') || 'assets/screenshots/placeholder-screen.svg';

  // Fallback cascade: .webp -> .png -> .svg
  if (currentSrc && currentSrc.toLowerCase().includes('.webp') && pngSrc) {
    imgElement.src = pngSrc;
  } else if (!currentSrc || !currentSrc.toLowerCase().includes('.svg')) {
    imgElement.src = fallbackSvg;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  // Initialize Lucide icons
  if (window.lucide) {
    window.lucide.createIcons();
  }

  // 1. Mobile Menu Toggle
  const mobileMenuBtn = document.getElementById('mobile-menu-btn');
  const mobileMenu = document.getElementById('mobile-menu');

  if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
    });

    const mobileLinks = mobileMenu.querySelectorAll('a');
    mobileLinks.forEach(link => {
      link.addEventListener('click', () => {
        mobileMenu.classList.add('hidden');
      });
    });
  }

  // 2. FAQ Accordion Toggle
  const faqToggles = document.querySelectorAll('.faq-toggle');
  faqToggles.forEach(toggle => {
    toggle.addEventListener('click', () => {
      const content = toggle.nextElementSibling;
      const icon = toggle.querySelector('.faq-icon');
      const isOpen = !content.classList.contains('hidden');
      
      // Close other accordions
      document.querySelectorAll('.faq-content').forEach(c => c.classList.add('hidden'));
      document.querySelectorAll('.faq-icon').forEach(i => i.style.transform = 'rotate(0deg)');
      
      if (!isOpen) {
        content.classList.remove('hidden');
        if (icon) icon.style.transform = 'rotate(180deg)';
      }
    });
  });

  // 2b. Papan nama stasiun pada pita lintasan KRL.
  // Nama berganti tepat saat rangkaian berangkat, memakai event
  // 'animationiteration' agar selalu sinkron dengan animasi CSS-nya.
  const stationNameEl = document.getElementById('tk-station-name');
  const stationTextEl = document.getElementById('tk-station-name-text');
  const trainEl = document.querySelector('.tk-train');

  if (stationNameEl && stationTextEl && trainEl) {
    const stationNames = [
    'Jakarta Kota', 'Jatinegara', 'Jayakarta', 'Juanda', 'Jurangmangu', 'Kalideres',
    'Kampung Bandan', 'Karet', 'Kebayoran', 'Kemayoran', 'Klender', 'Klender Baru', 'Kramat',
    'Kranji', 'Lenteng Agung', 'Maja', 'Mangga Besar', 'Manggarai', 'Matraman',
    'Metland Telagamurni', 'Nambo', 'Palmerah', 'Parung Panjang', 'Pasar Minggu',
    'Pasar Minggu Baru', 'Pasar Senen', 'Pesing', 'Pondok Cina', 'Pondok Jati', 'Pondok Rajeg',
    'Pondok Ranji', 'Poris', 'Rajawali', 'Rangkasbitung', 'Rawa Buaya', 'Rawa Buntu',
    'Sawah Besar', 'Serpong', 'Sudimara', 'Sudirman', 'Taman Kota', 'Tambun', 'Tanah Abang',
    'Tanah Tinggi', 'Tangerang', 'Tanjung Barat', 'Tanjung Priok', 'Tebet', 'Tenjo',
    'Tigaraksa', 'Universitas Indonesia', 'Universitas Pancasila', 'Ancol', 'Angke',
    'BNI City', 'Batu Ceper', 'Bekasi', 'Bekasi Timur', 'Bogor', 'Bojong Indah', 'Bojonggede',
    'Buaran', 'Cakung', 'Cawang', 'Cibinong', 'Cibitung', 'Cicayur', 'Cikarang', 'Cikini',
    'Cikoya', 'Cilebut', 'Cilejit', 'Cisauk', 'Citayam', 'Citeras', 'Daru', 'Depok',
    'Depok Baru', 'Duren Kalibata', 'Duri', 'Gambir', 'Gang Sentiong', 'Gondangdia', 'Grogol'
    ];

    let stationIndex = 0;

    // Nama panjang (mis. "Universitas Pancasila") tidak muat pada papan.
    // Kecilkan hurufnya secukupnya, seperti papan stasiun sungguhan.
    const fitStationName = () => {
      stationNameEl.style.removeProperty('--station-font');
      const available = stationNameEl.clientWidth;
      const needed = stationTextEl.scrollWidth;
      if (!available || needed <= available) return;
      const base = parseFloat(getComputedStyle(stationNameEl).fontSize);
      stationNameEl.style.setProperty('--station-font', (base * available / needed) + 'px');
    };

    const swapStationName = () => {
      stationIndex = (stationIndex + 1) % stationNames.length;
      stationNameEl.classList.add('is-swapping');
      setTimeout(() => {
        stationTextEl.textContent = stationNames[stationIndex];
        fitStationName();
        stationNameEl.classList.remove('is-swapping');
      }, 320);
    };

    fitStationName();
    window.addEventListener('resize', fitStationName);
    trainEl.addEventListener('animationiteration', swapStationName);
  }

  // 2c. Tombol uji suara pengingat pada kartu Alarm Sisa Stasiun.
  // Berkasnya berisi pengumuman "1 stasiun lagi" (menuju transit / tujuan)
  // persis rekaman aplikasi, disusul bell — sama seperti peringatan terakhir
  // saat perjalanan asli.
  const soundButtons = Array.from(document.querySelectorAll('.tk-sound-btn'));

  if (soundButtons.length) {
    let activePlayer = null;
    let activeButton = null;

    const stopActive = () => {
      if (activePlayer) {
        activePlayer.pause();
        activePlayer.currentTime = 0;
      }
      if (activeButton) activeButton.classList.remove('is-playing');
      activePlayer = null;
      activeButton = null;
    };

    soundButtons.forEach(btn => {
      const src = btn.getAttribute('data-sound');
      if (!src) return;

      // Dibuat sekali lalu dipakai ulang, supaya tidak mengunduh tiap klik.
      const audio = new Audio(src);
      audio.preload = 'none';
      audio.addEventListener('ended', stopActive);

      btn.addEventListener('click', () => {
        // Klik pada tombol yang sedang berbunyi = hentikan.
        if (activeButton === btn) {
          stopActive();
          return;
        }
        stopActive();
        activePlayer = audio;
        activeButton = btn;
        btn.classList.add('is-playing');
        audio.currentTime = 0;
        const played = audio.play();
        if (played && typeof played.catch === 'function') {
          played.catch(() => stopActive());
        }
      });
    });
  }

  // 3. Interactive Feature Showcase Slider (Next/Prev + Smooth 3D Flip Transitions)
  const slidesData = [
    {
      targetId: 'feature-tab-1',
      webpSrc: 'assets/screenshots/app-beranda.webp?v=5',
      title: 'Pantau Perjalanan Lebih Mudah',
      badge: 'Beranda'
    },
    {
      targetId: 'feature-tab-2',
      webpSrc: 'assets/screenshots/app-mulai-perjalanan.webp?v=5',
      title: 'Mulai Perjalanan dengan Mudah',
      badge: 'Mulai Perjalanan'
    },
    {
      targetId: 'feature-tab-3',
      webpSrc: 'assets/screenshots/app-pengingat.webp?v=5',
      title: 'Pengingat Sebelum Tiba',
      badge: 'Pengingat'
    },
    {
      targetId: 'feature-tab-4',
      webpSrc: 'assets/screenshots/app-urutan-stasiun.webp?v=5',
      title: 'Urutan Stasiun Selama Perjalanan',
      badge: 'Perjalanan Aktif'
    },
    {
      targetId: 'feature-tab-5',
      webpSrc: 'assets/screenshots/app-jadwal.webp?v=5',
      title: 'Keberangkatan Berikutnya',
      badge: 'Jadwal'
    },
    {
      targetId: 'feature-tab-6',
      webpSrc: 'assets/screenshots/app-peta.webp?v=5',
      title: 'Peta Jalur Commuter Line',
      badge: 'Peta'
    },
    {
      targetId: 'feature-tab-7',
      webpSrc: 'assets/screenshots/app-masuk.webp?v=5',
      title: 'Masuk dengan Mudah',
      badge: 'Akun'
    }
  ];


  const featureCards = Array.from(document.querySelectorAll('.feature-card-content'));
  const featureMockupImg = document.getElementById('showcase-mockup-img');
  const featureMockupTitle = document.getElementById('showcase-mockup-title');
  const featureMockupBadge = document.getElementById('showcase-mockup-badge');
  const showcaseCounters = document.querySelectorAll('#showcase-slide-counter, .showcase-slide-counter-desktop');
  const showcaseDots = Array.from(document.querySelectorAll('.showcase-dot'));

  let currentSlideIndex = 0;
  const totalSlides = slidesData.length;
  let isAnimating = false;

  function updateSlide(index, direction = 'next') {
    if (isAnimating) return;
    if (index < 0) index = totalSlides - 1;
    if (index >= totalSlides) index = 0;
    currentSlideIndex = index;

    const currentSlide = slidesData[currentSlideIndex];
    if (!currentSlide) return;

    // 1. Update Dots styling
    showcaseDots.forEach((dot, i) => {
      if (i % totalSlides === currentSlideIndex) {
        dot.classList.remove('bg-slate-200', 'w-2.5');
        dot.classList.add('bg-blue-600', 'w-7', 'sm:w-8');
      } else {
        dot.classList.remove('bg-blue-600', 'w-7', 'sm:w-8');
        dot.classList.add('bg-slate-200', 'w-2.5');
      }
    });

    // 2. Update Slide Counters
    showcaseCounters.forEach(counter => {
      counter.textContent = `0${currentSlideIndex + 1} / 0${totalSlides}`;
    });

    // 3. 3D Flip Spin Animation for Mockup Image
    if (featureMockupImg) {
      isAnimating = true;
      const flipOutClass = direction === 'next' ? 'mockup-flip-out-next' : 'mockup-flip-out-prev';
      const flipInClass = direction === 'next' ? 'mockup-flip-in-next' : 'mockup-flip-in-prev';

      // Phase 1: Flip Out (0 -> 90 deg)
      featureMockupImg.classList.remove('mockup-flip-out-next', 'mockup-flip-out-prev', 'mockup-flip-in-next', 'mockup-flip-in-prev');
      featureMockupImg.classList.add(flipOutClass);

      setTimeout(() => {
        // Phase 2: Swap source at edge-on 90 deg angle
        featureMockupImg.src = currentSlide.webpSrc;
        featureMockupImg.classList.remove(flipOutClass);
        featureMockupImg.classList.add(flipInClass);

        // Force browser layout reflow
        void featureMockupImg.offsetWidth;

        // Phase 3: Flip In (-90 deg -> 0 deg)
        setTimeout(() => {
          featureMockupImg.classList.remove(flipInClass);
          setTimeout(() => {
            isAnimating = false;
          }, 240);
        }, 20);
      }, 220);
    }

    // 4. Update Title & Badge
    if (featureMockupTitle && currentSlide.title) {
      featureMockupTitle.textContent = currentSlide.title;
    }
    if (featureMockupBadge && currentSlide.badge) {
      featureMockupBadge.textContent = currentSlide.badge;
    }

    // 5. Show matching content with smooth slide animation
    featureCards.forEach(card => {
      if (card.id === currentSlide.targetId) {
        card.classList.remove('hidden');
        card.classList.remove('animate-tab-content');
        void card.offsetWidth; // force reflow
        card.classList.add('animate-tab-content');
      } else {
        card.classList.add('hidden');
      }
    });

    if (window.lucide) {
      window.lucide.createIcons();
    }
  }

  // Delegated Click Handlers for Next, Prev, and Dot buttons
  document.addEventListener('click', (e) => {
    const nextBtn = e.target.closest('.showcase-next-btn, #showcase-next-btn');
    if (nextBtn) {
      e.preventDefault();
      updateSlide(currentSlideIndex + 1, 'next');
      return;
    }

    const prevBtn = e.target.closest('.showcase-prev-btn, #showcase-prev-btn');
    if (prevBtn) {
      e.preventDefault();
      updateSlide(currentSlideIndex - 1, 'prev');
      return;
    }

    const dotBtn = e.target.closest('.showcase-dot');
    if (dotBtn) {
      e.preventDefault();
      const dotIndex = showcaseDots.indexOf(dotBtn);
      if (dotIndex !== -1) {
        const targetIndex = dotIndex % totalSlides;
        const direction = targetIndex >= currentSlideIndex ? 'next' : 'prev';
        updateSlide(targetIndex, direction);
      }
      return;
    }
  });

  // 4. Download Notification Toast
  const downloadBtns = document.querySelectorAll('.btn-download-apk');
  const downloadToast = document.getElementById('download-toast');

  downloadBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      if (downloadToast) {
        downloadToast.classList.remove('translate-y-24', 'opacity-0');
        downloadToast.classList.add('translate-y-0', 'opacity-100');

        setTimeout(() => {
          downloadToast.classList.add('translate-y-24', 'opacity-0');
          downloadToast.classList.remove('translate-y-0', 'opacity-100');
        }, 4000);
      }
    });
  });

  // 5. Hero Image Auto-Switch every 10 seconds (Seamless Crossfade between Man and Woman)
  const heroImg1 = document.getElementById('hero-img-1');
  const heroImg2 = document.getElementById('hero-img-2');

  if (heroImg1 && heroImg2) {
    let showFirst = true;
    setInterval(() => {
      showFirst = !showFirst;
      if (showFirst) {
        heroImg1.classList.remove('opacity-0');
        heroImg1.classList.add('opacity-100');
        heroImg2.classList.remove('opacity-100');
        heroImg2.classList.add('opacity-0');
      } else {
        heroImg1.classList.remove('opacity-100');
        heroImg1.classList.add('opacity-0');
        heroImg2.classList.remove('opacity-0');
        heroImg2.classList.add('opacity-100');
      }
    }, 10000);
  }
});

