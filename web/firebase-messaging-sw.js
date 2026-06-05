importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCXEmYc4rOoArsDapIH2z5fvF-MvNFJ-y4',
  authDomain: 'fir-8bdb4.firebaseapp.com',
  projectId: 'fir-8bdb4',
  storageBucket: 'fir-8bdb4.firebasestorage.app',
  messagingSenderId: '347635239568',
  appId: '1:347635239568:web:b2e9e513f77c6dfc40a615',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Zelp';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});
