import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import LabSystem from '../app/lab-system';
import '../app/globals.css';
import '../app/system.css';
import '../app/segod-palette.css';
import './pages.css';
import '../app/responsive-final.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode><LabSystem/></StrictMode>,
);
