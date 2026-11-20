(function () {
  const STORAGE_KEY = 'cafego_live_demo_state_v1';
  const BRANCHES = [
    {
      id: 'branch-bgc',
      name: 'CafeGO BGC High Street',
      address: 'Bonifacio High Street, 9th Ave, Taguig',
      hours: '6:30 AM – 11:00 PM Daily',
      km: 1.4,
      eta: 12
    },
    {
      id: 'branch-makati',
      name: 'CafeGO Ayala Triangle',
      address: 'Ayala Triangle Gardens, Paseo de Roxas, Makati',
      hours: '6:00 AM – 10:30 PM Daily',
      km: 2.3,
      eta: 18
    },
    {
      id: 'branch-qc',
      name: 'CafeGO Katipunan Roastery',
      address: '318 Katipunan Ave, Loyola Heights, Quezon City',
      hours: '7:00 AM – 11:00 PM Daily',
      km: 6.8,
      eta: 28
    },
    {
      id: 'branch-manila',
      name: 'CafeGO Taft Malate',
      address: '2401 Taft Ave, Malate, Manila',
      hours: '6:30 AM – 10:00 PM Daily',
      km: 4.9,
      eta: 24
    }
  ];

  function buildDefaultState() {
    return {
      _rev: 1,
      storeOpen: true,
      selectedItemId: 'spanish-latte',
      editCartLineId: null,
      activeOrderId: 'BB842A',
      selectedAdminOrderId: 'BB842A',
      cashierOrderId: 'BB841C',
      pendingPayOrderId: 'BB842A',
      user: {
        uid: 'trKExqOCWsPqEOWEe1xnqiy7Q3S2',
        name: 'Customer User',
        email: 'customer@cafego.ph',
        phone: '+63912345604',
        role: 'customer',
        loyaltyStamps: 6,
        favorites: ['spanish-latte', 'sea-salt-cold-brew', 'butter-croissant'],
        addresses: [
          { id: 'home', label: 'Home', line: 'Unit 1204, High Street South, BGC, Taguig' },
          { id: 'office', label: 'Office', line: 'Ayala Triangle Tower 2, Makati' }
        ]
      },
      driver: {
        uid: 'RWy68IJ9vGMZo8TZM1MTVxRECXh1',
        name: 'Driver User',
        phone: '+63912345603',
        vehicle: 'Motorcycle',
        plate: 'ABC-1234',
        rating: 4.9,
        online: true,
        todayEarnings: 450,
        completedTrips: 10,
        activeOrderId: null
      },
      menu: [
        {
          id: 'spanish-latte',
          name: 'Spanish Latte',
          category: 'Hot Coffee',
          description: 'Double shot of signature espresso blended with velvety condensed milk and steamed fresh microfoam.',
          basePrice: 140,
          stock: 18,
          isAvailable: true,
          isHidden: false,
          isDrink: true,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'cappuccino',
          name: 'Cappuccino',
          category: 'Hot Coffee',
          description: 'Perfect balance of espresso, steamed milk and foam.',
          basePrice: 140,
          stock: 20,
          isAvailable: true,
          isHidden: false,
          isDrink: true,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'sea-salt-cold-brew',
          name: 'Sea Salt Caramel Cold Brew',
          category: 'Iced Coffee',
          description: '18-hour slow-steep cold brew topped with handcrafted salted caramel foam and raw turbinado sugar.',
          basePrice: 165,
          stock: 24,
          isAvailable: true,
          isHidden: false,
          isDrink: true,
          isIced: true,
          imageUrl: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'iced-spanish-latte',
          name: 'Iced Spanish Latte Royale',
          category: 'Iced Coffee',
          description: 'Bold dark roast espresso poured over chilled sweetened condensed milk and crystalline ice cubes.',
          basePrice: 150,
          stock: 16,
          isAvailable: true,
          isHidden: false,
          isDrink: true,
          isIced: true,
          imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'matcha-latte',
          name: 'Ceremonial Uji Matcha Latte',
          category: 'Non-Coffee',
          description: 'First-harvest ceremonial grade Japanese green tea stone-ground in Kyoto, whisked with textured creamy milk.',
          basePrice: 160,
          stock: 14,
          isAvailable: true,
          isHidden: false,
          isDrink: true,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'butter-croissant',
          name: 'French Butter Artisan Croissant',
          category: 'Pastries',
          description: 'Baked daily with imported French Lescure butter, creating thousands of delicate honeycomb golden flakes.',
          basePrice: 95,
          stock: 3,
          isAvailable: true,
          isHidden: false,
          isDrink: false,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'burnt-basque-cheesecake',
          name: 'Burnt Basque Cheesecake Slice',
          category: 'Pastries',
          description: 'Caramelized dark exterior with an ultra-creamy, molten-soft cream cheese center infused with vanilla bean.',
          basePrice: 160,
          stock: 10,
          isAvailable: true,
          isHidden: false,
          isDrink: false,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'cafego-beans-ethiopia',
          name: 'CafeGO Reserve Ethiopia Yirgacheffe (250g)',
          category: 'Merch',
          description: 'Single-origin heirloom Arabica beans with vibrant notes of bergamot, peach, and jasmine.',
          basePrice: 390,
          stock: 12,
          isAvailable: true,
          isHidden: false,
          isDrink: false,
          isIced: false,
          imageUrl: 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?auto=format&fit=crop&w=600&q=80'
        }
      ],
      cart: [
        {
          id: 'line_1',
          itemId: 'spanish-latte',
          name: 'Spanish Latte',
          qty: 1,
          unitPrice: 170,
          summary: 'Medium • Oat (+₱30) • 2 Shots • 100%',
          size: 'Medium',
          milk: 'Oat',
          shots: 2,
          sugar: '100%',
          ice: null,
          addons: [],
          note: 'Extra hot please',
          imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80'
        },
        {
          id: 'line_2',
          itemId: 'butter-croissant',
          name: 'French Butter Artisan Croissant',
          qty: 1,
          unitPrice: 95,
          summary: '',
          size: null,
          milk: null,
          shots: null,
          sugar: null,
          ice: null,
          addons: [],
          note: '',
          imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80'
        }
      ],
      orders: [
        {
          id: 'BB842A',
          userName: 'Maria Clara Santos',
          status: 'received',
          type: 'delivery',
          branchId: 'branch-bgc',
          branchName: 'CafeGO BGC High Street',
          address: 'Unit 1204, High Street South, BGC, Taguig',
          payment: 'GCash',
          paymentStatus: 'paid',
          subtotal: 265,
          deliveryFee: 45,
          discount: 0,
          total: 310,
          note: 'Extra hot please',
          createdAt: Date.now() - 4 * 60000,
          driverId: null,
          driverName: null,
          driverStatus: null,
          riderProgress: 0.15,
          rating: null,
          items: [
            {
              itemId: 'spanish-latte',
              name: 'Spanish Latte',
              qty: 1,
              total: 170,
              summary: 'Medium • Oat (+₱30) • 2 Shots • 100%',
              note: 'Extra hot please',
              imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80'
            },
            {
              itemId: 'butter-croissant',
              name: 'French Butter Artisan Croissant',
              qty: 1,
              total: 95,
              summary: '',
              note: '',
              imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80'
            }
          ]
        },
        {
          id: 'BB841C',
          userName: 'Juan Dela Cruz',
          status: 'preparing',
          type: 'pickup',
          branchId: 'branch-bgc',
          branchName: 'CafeGO BGC High Street',
          address: null,
          payment: 'Pay at counter',
          paymentStatus: 'pending',
          subtotal: 140,
          deliveryFee: 0,
          discount: 0,
          total: 140,
          note: '',
          createdAt: Date.now() - 7 * 60000,
          driverId: null,
          driverName: null,
          driverStatus: null,
          riderProgress: 0,
          rating: null,
          items: [
            {
              itemId: 'cappuccino',
              name: 'Cappuccino',
              qty: 1,
              total: 140,
              summary: 'Medium • Whole • 2 Shots • 100%',
              note: '',
              imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?auto=format&fit=crop&w=600&q=80'
            }
          ]
        },
        {
          id: 'AA1904',
          userName: 'Andrea Reyes',
          status: 'completed',
          type: 'delivery',
          branchId: 'branch-makati',
          branchName: 'CafeGO Ayala Triangle',
          address: 'Salcedo Village, Makati',
          payment: 'Maya',
          paymentStatus: 'paid',
          subtotal: 160,
          deliveryFee: 45,
          discount: 0,
          total: 205,
          note: '',
          createdAt: Date.now() - 48 * 60000,
          driverId: 'RWy68IJ9vGMZo8TZM1MTVxRECXh1',
          driverName: 'Driver User',
          driverStatus: 'delivered',
          riderProgress: 1.0,
          rating: 5,
          items: [
            {
              itemId: 'matcha-latte',
              name: 'Ceremonial Uji Matcha Latte',
              qty: 1,
              total: 160,
              summary: 'Large • Soy • 75%',
              note: '',
              imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=600&q=80'
            }
          ]
        }
      ],
      usersDirectory: [
        { uid: '8sJe87j7TMM0cCzGsuM4YkPMZeA2', name: 'Admin User', email: 'admin@cafego.ph', phone: '+63912345601', role: 'admin' },
        { uid: 'Es1dTJTuIjcUnp0dvQSR9oWeRJl2', name: 'Staff User', email: 'staff@cafego.ph', phone: '+63912345602', role: 'staff' },
        { uid: 'RWy68IJ9vGMZo8TZM1MTVxRECXh1', name: 'Driver User', email: 'driver@cafego.ph', phone: '+63912345603', role: 'driver' },
        { uid: 'trKExqOCWsPqEOWEe1xnqiy7Q3S2', name: 'Customer User', email: 'customer@cafego.ph', phone: '+63912345604', role: 'customer' }
      ]
    };
  }

  let cachedState = null;
  const listeners = [];

  function loadLocal() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return JSON.parse(raw);
    } catch (_) {}
    const def = buildDefaultState();
    saveLocal(def);
    return def;
  }

  function saveLocal(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (_) {}
  }

  function notifyListeners(state) {
    cachedState = state;
    listeners.forEach(fn => {
      try { fn(state); } catch (_) {}
    });
  }

  function getState() {
    if (!cachedState) cachedState = loadLocal();
    return cachedState;
  }

  function setState(mutator) {
    const current = JSON.parse(JSON.stringify(getState()));
    const next = mutator(current) || current;
    next._rev = (current._rev || 1) + 1;
    saveLocal(next);
    notifyListeners(next);
    if (window.parent && window.parent !== window) {
      window.parent.postMessage({ type: 'CAFEGO_STATE_PUSH', state: next }, '*');
    }
    return next;
  }

  function resetDemo() {
    const def = buildDefaultState();
    saveLocal(def);
    notifyListeners(def);
    if (window.parent && window.parent !== window) {
      window.parent.postMessage({ type: 'CAFEGO_STATE_PUSH', state: def }, '*');
    }
    return def;
  }

  function onUpdate(fn) {
    listeners.push(fn);
    if (document.readyState !== 'loading') {
      fn(getState());
    } else {
      window.addEventListener('DOMContentLoaded', () => fn(getState()));
    }
  }

  function peso(n) {
    return '₱ ' + Number(n || 0).toFixed(2);
  }

  function statusLabel(status) {
    const map = {
      received: 'Received',
      preparing: 'Preparing',
      ready: 'Ready for pickup',
      completed: 'Completed',
      cancelled: 'Cancelled'
    };
    return map[status] || status;
  }

  function updateNavBadges(state) {
    const count = (state.cart || []).reduce((s, c) => s + (c.qty || 0), 0);
    document.querySelectorAll('.nav-badge[data-cart-badge]').forEach(el => {
      el.textContent = count;
      el.style.display = count > 0 ? 'flex' : 'none';
    });
  }

  // Detect embedded iframe mode cleanly (removes outer bezel padding/shadow inside showcase)
  if (window.self !== window.top) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('in-frame');
      window.parent.postMessage({ type: 'CAFEGO_PULL_STATE' }, '*');
    });
  }

  function findDemoElement(selector, textMatch, index) {
    const nodes = Array.from(document.querySelectorAll(selector || 'button, a'));
    const filtered = nodes.filter(el => {
      const style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden') return false;
      if (textMatch) {
        return (el.textContent || '').trim().toLowerCase().includes(textMatch.toLowerCase());
      }
      return true;
    });
    return filtered[index || 0] || null;
  }

  // Cross-frame message sync & deterministic cursor automation bridge
  window.addEventListener('message', (e) => {
    const data = e.data;
    if (!data || typeof data !== 'object') return;
    if (data.type === 'CAFEGO_STATE_SYNC' && data.state) {
      const incoming = data.state;
      const cur = getState();
      if (!cur || incoming._rev !== cur._rev) {
        saveLocal(incoming);
        notifyListeners(incoming);
      }
      return;
    }

    if (data.type === 'CAFEGO_QUERY_RECT') {
      const el = findDemoElement(data.selector, data.textMatch, data.index);
      if (!el) {
        window.parent.postMessage({ type: 'CAFEGO_RECT_REPLY', reqId: data.reqId, rect: null }, '*');
        return;
      }
      const r0 = el.getBoundingClientRect();
      const needsScroll = r0.top < 46 || r0.bottom > (window.innerHeight - 28);
      if (needsScroll) {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        setTimeout(() => {
          const r1 = el.getBoundingClientRect();
          window.parent.postMessage({
            type: 'CAFEGO_RECT_REPLY',
            reqId: data.reqId,
            rect: { left: r1.left, top: r1.top, width: r1.width, height: r1.height }
          }, '*');
        }, 280);
      } else {
        window.parent.postMessage({
          type: 'CAFEGO_RECT_REPLY',
          reqId: data.reqId,
          rect: { left: r0.left, top: r0.top, width: r0.width, height: r0.height }
        }, '*');
      }
    } else if (data.type === 'CAFEGO_EXEC_CLICK') {
      const el = findDemoElement(data.selector, data.textMatch, data.index);
      if (el) {
        el.focus && el.focus();
        el.click();
      }
    } else if (data.type === 'CAFEGO_TYPE') {
      const el = findDemoElement(data.selector, data.textMatch, data.index);
      if (el) {
        el.focus && el.focus();
        el.value = data.value || '';
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      }
    } else if (data.type === 'CAFEGO_SCROLL') {
      const scroller = document.querySelector('.screen-scroll');
      if (scroller) scroller.scrollTo({ top: data.y || 0, behavior: 'smooth' });
    }
  });

  // Fallback same-origin storage sync for multi-tab testing
  window.addEventListener('storage', (e) => {
    if (e.key === STORAGE_KEY && e.newValue) {
      try {
        notifyListeners(JSON.parse(e.newValue));
      } catch (_) {}
    }
  });

  window.CafeDemo = {
    BRANCHES,
    getState,
    setState,
    resetDemo,
    onUpdate,
    peso,
    statusLabel,
    updateNavBadges,
    buildDefaultState
  };
})();
