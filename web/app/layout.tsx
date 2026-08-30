import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';
const sans=Geist({variable:'--font-sans',subsets:['latin']}); const mono=Geist_Mono({variable:'--font-mono',subsets:['latin']});
export const metadata:Metadata={title:'SEGOD Laboratorio',description:'Gestión de muestras, ensayos y datos crudos del laboratorio SEGOD.'};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="es"><body className={`${sans.variable} ${mono.variable}`}>{children}</body></html>;}
