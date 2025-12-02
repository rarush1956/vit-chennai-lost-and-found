function onGoogleSignIn(googleUser) {
  const idToken = googleUser.credential;
  window.flutter_inappwebview.callHandler('googleSignIn', idToken);
}