import '../models/shelter.dart';

// Bangkok flood evacuation centres and permanent shelters from the BMA directory (Bangkok
// Shelters and Flood Relief Centers Directory). Positions were looked up by place name in
// OpenStreetMap; capacity is not published, so it is left empty. Places whose position could not be
// found by name are left out rather than guessed: Thai-Japanese Youth Center, Chaloem Phrakiat 72nd
// Anniversary Sports Center, and the permanent shelters Protection Center for the Destitute,
// Baan Mitmaitri (Sai Mai, On Nut), Bangkok Emergency Home, Baan Phra Phon, Mercy Centre and
// Mirror Foundation.
//
// The ids starting with d come from the 2026 temporary-shelter roster: only the few schools and
// campuses there that print their own coordinates are included.
const bangkokShelters = <Shelter>[
  Shelter(
    id: 't2',
    name: 'Bangkok Arena (Nong Chok)',
    lat: 13.83272,
    lng: 100.84963,
    phone: '02-543-1472',
  ),
  Shelter(
    id: 't4',
    name: 'Wachirabenchathat Park (Rot Fai Park)',
    lat: 13.81182,
    lng: 100.55367,
    phone: '02-513-3444',
  ),
  Shelter(
    id: 't5',
    name: 'Wat Pariwat',
    lat: 13.67352,
    lng: 100.53313,
    phone: '02-294-2393',
  ),
  Shelter(
    id: 't6',
    name: 'Wat Dokmai',
    lat: 13.68248,
    lng: 100.52654,
    phone: '02-294-2393',
  ),
  Shelter(
    id: 't7',
    name: 'Wat Bang Na Nai',
    lat: 13.67064,
    lng: 100.60401,
    phone: '02-173-5253',
  ),
  Shelter(
    id: 't8',
    name: 'Wat Bang Na Nok',
    lat: 13.67579,
    lng: 100.58761,
    phone: '02-173-5253',
  ),
  Shelter(
    id: 't9',
    name: 'Wat Mai Yai Nui',
    lat: 13.71193,
    lng: 100.46861,
    phone: '02-413-0565',
  ),
  Shelter(
    id: 't10',
    name: 'Wat Nang Chi',
    lat: 13.71859,
    lng: 100.46156,
    phone: '02-413-0565',
  ),
  Shelter(
    id: 't11',
    name: 'Wat Amarinthraram',
    lat: 13.76006,
    lng: 100.48360,
    phone: '02-424-6847',
  ),
  Shelter(
    id: 't12',
    name: 'Wat Rakhangkhositaram',
    lat: 13.75257,
    lng: 100.48564,
    phone: '02-424-6847',
  ),
  Shelter(
    id: 't13',
    name: 'Wat Krathum Suea Pla',
    lat: 13.72298,
    lng: 100.68900,
    phone: '02-328-7149',
  ),
  Shelter(
    id: 't14',
    name: 'Wat Lan Boon',
    lat: 13.72495,
    lng: 100.72027,
    phone: '02-326-9149',
  ),
  Shelter(
    id: 't15',
    name: 'Wat Don Mueang',
    lat: 13.92238,
    lng: 100.60105,
    phone: '02-565-9424',
  ),
  Shelter(
    id: 't16',
    name: 'Wat Phra Sri Mahathat',
    lat: 13.87436,
    lng: 100.59720,
    phone: '02-521-0666',
  ),
  Shelter(
    id: 'p2',
    name: 'Baan Mitmaitri (Din Daeng)',
    lat: 13.76362,
    lng: 100.55335,
    phone: '02-246-8661',
  ),
  Shelter(
    id: 'd1',
    name: 'Chandrakasem Rajabhat University',
    lat: 13.819084,
    lng: 100.576455,
    phone: '094-242-4571',
  ),
  Shelter(
    id: 'd2',
    name: 'Wat Weluwanaram School',
    lat: 13.914165,
    lng: 100.567276,
    phone: '080-560-2828',
  ),
  Shelter(
    id: 'd3',
    name: 'Wat Suttharam School',
    lat: 13.71257,
    lng: 100.4938,
    phone: '02-249-4499',
  ),
  Shelter(
    id: 'd4',
    name: 'Phranakhon Rajabhat University (Phutthavichalai Building)',
    lat: 13.877699,
    lng: 100.591621,
    phone: '02-521-0057',
  ),
  Shelter(id: 'd5', name: 'Bang Phai School', lat: 13.75037, lng: 100.35487),
];
