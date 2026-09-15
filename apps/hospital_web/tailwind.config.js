/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50:  '#eef9ff',
          100: '#d9f1ff',
          200: '#bce6ff',
          300: '#8ed5ff',
          400: '#59bafb',
          500: '#1a9de0',
          600: '#0f82c4',
          700: '#0d699f',
          800: '#0f5883',
          900: '#13496d',
        },
        slate: {
          850: '#172033',
        },
      },
    },
  },
  plugins: [],
}
