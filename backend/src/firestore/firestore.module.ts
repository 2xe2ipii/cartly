import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { existsSync } from 'node:fs';
import { isAbsolute } from 'node:path';

export const FIRESTORE = Symbol('FIRESTORE');

@Module({
  providers: [
    {
      provide: FIRESTORE,
      inject: [ConfigService],
      useFactory: (config: ConfigService): Firestore => {
        const projectId = config.getOrThrow<string>('GOOGLE_CLOUD_PROJECT');
        const credentialsPath = config.getOrThrow<string>(
          'GOOGLE_APPLICATION_CREDENTIALS',
        );

        if (!isAbsolute(credentialsPath) || !existsSync(credentialsPath)) {
          throw new Error(
            'GOOGLE_APPLICATION_CREDENTIALS must point to an existing absolute file',
          );
        }

        const app = initializeApp({ credential: applicationDefault(), projectId });
        return getFirestore(app);
      },
    },
  ],
  exports: [FIRESTORE],
})
export class FirestoreModule {}
