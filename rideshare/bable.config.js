module.exports = function(api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      // Handle React Native reanimated
      'react-native-reanimated/plugin',
    ],
    // Add module resolver to handle problematic modules
    env: {
      production: {
        plugins: ['transform-remove-console'],
      },
    },
  };
};