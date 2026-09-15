# TOSUMO Doctor — Capability Matrix (Phase 0 Audit)

Backend contract verified from source at `backend/src` (Express 4 + TS + Prisma 5 Mongo, Socket.IO `SOCKET_PATH=/ws`, JWT access 15m / refresh 7d, OTP demo mode accepts any 6-digit code, envelope `{success, data}`).

Doctor app `flutter analyze` passes (1 trivial warning: `assets/images/` missing). Tests: none exist yet.

## Auth

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Login (email+password) | `POST /api/v1/auth/login` `{email,password}` | `login(email,password)` wired | OK, but doctor entry is OTP-first |
| Login (phone OTP demo) | `POST /api/v1/auth/send-otp` `{phone}` → `{mode}`, `POST /api/v1/auth/otp-login` `{phone,code}` (any 6-digit) | **Missing** — no OTP path in `AuthRepository`/screens | Add `otpLogin` + OTP screen. Phone normalized by backend (`+237…`) |
| Register (doctor) | `POST /api/v1/auth/register` `{phone,password,role}` → `{success,message,data:{user,tokens}}`; then `POST /api/v1/doctors/register` `{firstName,lastName,specialty,licenseNumber,…}` | Auth `register` unused | Wire register flow (Phase 28 demo uses seeded accounts instead) |
| Refresh | `POST /api/v1/auth/refresh` `{refreshToken}` → `{data:{tokens:{accessToken,refreshToken}}}` | `AuthInterceptor` refresh+retry present (separate Dio, works with raw envelope) | Retry uses bare `Dio().fetch` → response NOT unwrapped; verify downstream parse |
| Logout | `POST /api/v1/auth/logout` (auth) | Wired, ignores errors | OK |
| Profile | `GET /api/v1/auth/profile` | `authCheck` uses it | OK |
| Auto-login / restore | — | `AuthState` reads `user_id` from secure storage directly (key drift risk), **no refresh validation, no bootstrap** | Phase 1 rewrite: tryAutoLogin→refresh→bootstrap (socket+profile+dashboard), bounded timeout, offline-safe |
| Token storage | — | `TokenStorageService` (secure storage, keys match `AppConstants`) BUT `RemoteDoctorRepository.login` writes literal keys `auth_token/refresh_token/user_id` to a separate `FlutterSecureStorage` instance | Single storage source; add file-mirror fallback (patient pattern); remove literal-key writes |
| doctorId vs userId | doctor doc id ≠ user id | `AuthState.doctorId = userId` (wrong) | After login fetch real `Doctor` via `/doctors/profile`; dashboard/profile take **userId**; analytics wrongly takes doctorId |
| Splash gate / redirect | — | Router starts at `/` = LoginScreen, **no redirect, no splash** | Phase 1 add splash + redirect, StatefulShellRoute for tabs |
| Localization | — | `assets/translations/{en,fr}.json` + `AppLocalization.t()` exist but login screen uses hardcoded French | Wire `t()` everywhere (Phase 25) |

## Doctor profile / availability

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Get profile | `GET /doctors/profile` (userId) | ✓ `getProfile` correct | OK |
| Update profile | `PUT /doctors/profile` (whitelist fields) | `updateProfile` PUTs `GET /doctors/:id` path — **wrong** | Change to `PUT /doctors/profile`; coordinator enqueues `/doctors/{id}` PUT — fix |
| Set available toggle | `PUT /doctors/availability-status` `{isAvailable}` | ✓ | OK |
| Weekly availability | `GET/PUT /doctors/availability` (slots `[{dayOfWeek,startTime,endTime,isAvailable,slotDuration}]`) | Endpoint declared; repo uses `updateWorkingHours` against fake `/api/v1/settings` | Add get/set availability to repo+screen |
| Working hours override | `GET/PUT /doctors/working-hours` `{hours:[{date,startTime,endTime,isAvailable,reason}]}` | Fake `/settings` route | Repoint to `/doctors/working-hours` |
| Institution affiliation | `GET /doctors/institutions` (doctorInstitution incl. institution) | declared endpoint only | Phase 19 |
| Reviews | `GET /doctors/reviews` | declared | Phase 19 |

## Appointments

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| List (status filter) | `GET /doctors/appointments?status=` | `getAppointments` ✓ (page/limit ignored — fine) | OK |
| "Today"/"Weekly" lists | not supported server-side | `filter=today/weekly` query — **wrong** | Filter client-side from `getAppointments` |
| Upcoming | `GET /appointments/upcoming` (patient) | unused | Doctor uses `/doctors/appointments?status=` list |
| Detail | `GET /appointments/:id` (owner or admin) | ✓ | OK |
| Approve | `PUT /appointments/:id/approve` (doctor, pending→approved) | ✓ `approveAppointment` | OK |
| Reject | no reject route | `rejectAppointment` PUTs `/confirm` (patient-only) — **wrong** | Reject = `PUT /:id/cancel` with reason |
| Cancel | `PUT /appointments/:id/cancel` `{reason}` (patient|doctor|admin) | `cancelAppointment` ✓ body `{reason}` | OK |
| Confirm | `PUT /:id/confirm` (patient) | endpoint named `appointmentReject`→confirm — unused by doctor | Not doctor action; drop/rename |
| Reschedule | `PUT /:id/reschedule` `{appointmentDate,startTime,endTime,reason?}` | body `{date,timeSlot}` — **wrong** | Fix body shape |
| Complete | `PUT /:id/complete` (doctor, approved/confirmed/rescheduled→completed) | ✓ `completeAppointment` | OK |
| No-show | `PUT /:id/no-show` (doctor) | **not in endpoints** | Add |
| Available slots | `GET /appointments/available-slots?doctorId&date` | unused | Phase 4 detail |
| Book | `POST /appointments` (patient-driven, injects patientId) | doctor `bookAppointment` would fail (no patient profile) | Remove doctor-side book (patient books); or repurpose |
| Real-time | `appointment:new`, `appointment:updated`, `appointment:cancelled`, `appointment:rescheduled`, `appointment:completed` → user room | socket listens new/updated/cancelled/completed (not rescheduled) | Add `appointment:rescheduled`; remove bogus `emergency:sos` |

## Patients & access

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Search | `GET /doctors/patients/search?query=` (name/NIN/phone/card, 20) | `searchPatients` uses `GET /api/v1/patients/search?q=` — **wrong path+param** | Repoint; single `query` param (searchByFilters is fake) |
| QR lookup | `GET /doctors/patients/qr?cardNumber=` → `{patient, access}` | `POST /patients/qr` body `{qrData}` — **wrong** | Repoint to GET query param; parse `{patient, access}` |
| Patient detail | `GET /patients/:id` (doctor allowed if active access or emergency session) | `getPatientById` ✓ | OK, but mapper must tolerate access-denied 403 |
| My patients | `GET /doctors/patients` (distinct appointment patients) | `getRecentPatients` ✓ | OK |
| Favorite | none | `toggleFavorite` PATCH `/patients/:id` — **fake** | Remove (or local-only) |
| Request access | `POST /access/request` `{patientId,accessLevel?,reason?}` (doctor→patient, 30d, pending) | **not implemented** | Phase 7 |
| Grant access | `POST /access/grant` (patient→doctor) | not implemented | patient-side; doctor sees via socket `access:granted` |
| Approve | `PUT /access/:id/approve` (patient) | not implemented | patient-side |
| Revoke | `PUT /access/:id/revoke` `{reason}` (either party) | not implemented | Phase 7 |
| My accesses (doctor) | `GET /access/doctor` | not implemented | Phase 7 |
| Check | `GET /access/check/:patientUserId` | not implemented | Phase 7 |
| Real-time | `access:granted`, `access:request`, `access:approved`, `access:revoked`, `emergency:access-granted` | **not registered** | Add socket handlers |

## Medical records (doctor writes + aggregate read)

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Aggregate view | `GET /medical-records/patient/:patientId` (doctor-only, requires active access/session or own record) → `{consultations,labResults,imagingResults,prescriptions}` | `getPatientRecords` not implemented; repo uses per-entity `/patient/:id` routes that don't exist | Phase 8: use aggregate for patient chart |
| Create consultation | `POST /medical-records/consultations` `{patientId,appointmentId?,chiefComplaint,historyOfPresentIllness?,diagnosis?,symptoms?,vitalSigns?,assessment?,plan?,notes?}` | `createConsultation` POSTs `consultation.toJson()` — field names differ | Fix model→contract mapping |
| Update consultation | `PUT /consultations/:id` (owner doctor) | `updateDraft` PUT ✓; `finalize`/`sign`/`pdf` are PATCH to non-existent routes — **fake** | Remove finalize/sign/pdf or repurpose to PUT update |
| Vital signs | part of consultation create/update payload | `saveVitalSigns` PATCH `/consultations/:id` — **wrong method+shape** | Fold into consultation update |
| Create prescription | `POST /prescriptions` `{patientId,medicationName,dosage,frequency,duration,route?,instructions?,refills?,pharmacyName?}` | `createPrescription` POSTs model — fields differ | Fix mapping |
| Fulfill | `PUT /prescriptions/:id/fulfill` (doctor/admin) | `renewPrescription` PATCH `/renew` — **fake** | Use fulfill (real pharmacist/doctor action) |
| Update prescription | `PUT /prescriptions/:id` | `cancelPrescription` PATCH `/prescriptions/:id` — wrong method | Fix |
| Lab results | entity = **LabResult** (no LabRequest). Create `{patientId,testName,testCategory,resultData?,resultFileUrl?,laboratoryName?,notes?}`, update `PUT /lab-results/:id`, list `GET /lab-results` (role-scoped) | Model `LabRequest`; routes `/lab-results/patient/:id` and `?doctorId&status` — **wrong** | Rename model LabResult, use aggregate + list; update via PUT |
| Imaging results | entity = **ImagingResult** (no ImagingRequest). Create `{patientId,imagingType,bodyPart?,imageUrls?,reportText?,reportFileUrl?,facilityName?,notes?}`, update `PUT /imaging-results/:id` | Model `ImagingRequest`; same route problems | Same fix |

## Chat

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Conversations | `GET /chat` (participant) | `getConversations` ✓ | OK |
| Messages | `GET /chat/:chatId/messages?limit=50&before=` (cursor) | `getMessages` sends `page/limit` — page unsupported | Use `limit`/`before` cursor |
| Send | `POST /chat/:chatId/messages` `{content?,messageType?,fileUrl?,fileSize?,mimeType?,replyToId?}` | sends `{text,type}` — **wrong fields** | Fix to `content`/`messageType` |
| Mark read | `PUT /chat/:chatId/read` | `markAsRead` declared; `markMessageDelivered` PATCH `/chat/messages/:id` — **fake** | Fix method; drop delivered |
| Unread count | `GET /chat/unread` → `{count}` | `chatUnread` declared | OK |
| Real-time | `message:new`, `chat:read`, `typing:start/stop` (chat rooms) | socket listens message:new, typing; **no chat:read** | Add `chat:read`; wire `joinChat` on open |

## Notifications

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| List | `GET /notifications` | `getNotifications` ✓ | OK |
| Unread list | `GET /notifications/unread` | `getUnreadNotifications` ✓ | OK |
| Unread count | `GET /notifications/unread/count` → `{count}` | **not in endpoints** | Add |
| Mark read | `PUT /notifications/:id/read` | `markAsRead` PATCH — **wrong method** | Use PUT |
| Mark all read | `PUT /notifications/read-all` | PATCH — **wrong method** | Use PUT |
| Delete | `DELETE /notifications/:id` | **not implemented** | Add |
| Real-time | backend sends notifications via REST; socket has `notification:new`? (not in socket index audit) | socket registers `notification:new`/`notification:updated` | Verify backend emits; if not, rely on REST + unread count refresh |

## Emergency

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| List sessions | `GET /emergency/sessions` (current doctor, optional `?status=`) | `getEmergencyHistory` GETs `/sessions/:doctorId` — **wrong** | Use `/sessions` |
| Active session | `GET /emergency/sessions/active` (doctor) | `getActiveSession` GET `/emergency/active?doctorId=` — **wrong** | Repoint, drop doctorId query (server uses auth) |
| Session detail | `GET /emergency/sessions/:id` | — | Add |
| Start/ack | `POST /emergency/sessions` `{patientId,justification?}` (adopts incoming, creates 24h emergency access) | `startEmergencySession` POSTs `/emergency/sos` — **wrong** | Repoint to `/sessions` |
| Update status | `PATCH /emergency/sessions/:id` `{status}` (acknowledged/active/resolved/ended/void) | `completeEmergencySession` PATCHes `/sos` — **wrong** | Repoint to `/sessions/:id` |
| Critical info | `GET /emergency/critical-info/:patientId` (doctor with session/access) | `getEmergencyPatientSummary` GET `/patients/:id?summary=emergency` — **fake** | Repoint |
| Nearby hospitals | `GET /emergency/nearby-hospitals?latitude&longitude&radiusKm` | **not implemented** | Phase 16 |
| Real-time | `emergency:new-session` (doctors w/ relationship + verified available), `emergency:session-updated`, `emergency:contact-alert` | listens `emergency:sos` (**wrong event**) | Register `emergency:new-session`, `emergency:session-updated` |

## Dashboard / analytics / settings

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Dashboard | `GET /doctors/dashboard` → `{stats:{totalAppointments,todayAppointments,pendingApprovals,totalPatients},recentAppointments,upcomingAppointments}` | `getDashboardStats` ✓ | OK |
| Stats | `GET /doctors/stats` → `{totalAppointments,completedAppointments,cancelledAppointments,averageRating}` | `getDoctorStats` uses fake `/api/v1/analytics/doctor/:id` — **no such module** | Repoint to `/doctors/stats` |
| Diagnosis distribution / completion / trends | no endpoints | fake `/analytics/doctor/:id/*` | Remove or derive from dashboard/stats client-side |
| Settings (language/theme/pin/biometric/offline) | **no settings module** | PATCH `/api/v1/settings` — **fake** | Persist locally (secure storage/shared prefs); theme/locale already local |
| FCM token | `PUT /auth/fcm-token` `{fcmToken}` | **not implemented** | Phase 27 |

## Offline / quality

| Capability | Backend | Doctor app today | Gap / Action |
|---|---|---|---|
| Offline-first reads | coordinator `_fetchWithFallback` (10s timeout → local) | present | Fix `setOnline(false)` sticky-once-failed (no retry re-enable on next op?) — verify |
| Write-through | `_enqueueSync` PUT/POST to sync queue | enqueues **wrong endpoints** (e.g. `/doctors/{id}`) | Fix to real endpoints; queue is in-memory only (not persisted) — persist |
| Local cache | Hive `LocalDatabase` (`getAll/putAll/getById`) | `putAll` reuses existing keys instead of clear+add → **stale rows persist** | Adopt patient clear+add |
| Errors | — | `ErrorInterceptor` + `ErrorMapper` exist | Ensure UI surfaces `ErrorMapper` messages, never raw DioException |

## Demo accounts (Phase 28)

| Account | Phone | Password | Notes |
|---|---|---|---|
| Patient | `+237691234567` | `Demo@1234` (deployed password `Asonte@6900`) | user `74285db531ea5990628597b6`, demo@tosumo.cm |
| GP (Théodore Nkoulou) | `+237691000101` | `Demo@1234` | demo.gp@tosumo.cm. Patient = Jean-Pierre Mballa |
| Cardiologist | `+237691000102` | `Demo@1234` | demo.cardio@tosumo.cm |
| Pediatrician | `+237691000103` | `Demo@1234` | demo.peds@tosumo.cm |
| Dermatologist | `+237691000104` | `Demo@1234` | demo.derm@tosumo.cm |
| Gynecologist | `+237691000105` | `Demo@1234` | demo.gyno@tosumo.cm |

All 5 demo doctors have full 7-day availability (08:00–17:00, 30min) + an upcoming working-hours override in seed-demo.

## Top blocking defects to fix (in priority order)

1. **baseUrl**: `DoctorApiEndpoints.baseUrl` hardcodes `https://api.tosumo.cm` (release) / `10.0.2.2:3456` (debug). Must mirror patient `String.fromEnvironment('API_BASE_URL', default Railway prod / localhost:3456)`.
2. **Auth restore**: no OTP login, no refresh-based auto-login, no bootstrap, `doctorId=userId` wrong, key drift between `TokenStorageService` and literal-key writes, live `/auth/profile` call on startup breaks offline.
3. **Routing/splash**: no auth redirect, no splash, no shell, login screen hardcoded FR.
4. **Fake endpoints**: `/api/v1/analytics/*`, `/api/v1/settings*`, `/consultations/:id/finalize|sign|pdf`, `/prescriptions/:id/renew`, patient favorites, `/chat/messages/:id`, doctor-side booking. Remove or repoint.
5. **Contract mismatches**: QR (GET+cardNumber), search (query param), reschedule body, emergency routes/events, lab/imaging entity naming (LabResult/ImagingResult), chat send fields, notification PUT methods, availability/working-hours routes.
6. **`seed_data_generator.dart`** contains hardcoded fake patients/doctors/appointments (incl. real person names) — delete (unused).
7. **LocalDatabase.putAll** stale-key reuse — adopt clear+add like patient app.
