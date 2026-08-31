import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import LabSystem from '../app/lab-system';
import '../app/globals.css';
import './pages.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode><LabSystem/></StrictMode>,
);
