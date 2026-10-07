import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { join } from 'node:path';

import { UserIdGuard } from './common/user-id.guard';
import { ItemsModule } from './items/items.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: join(__dirname, '..', '.env'),
    }),
    ItemsModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: UserIdGuard }],
})
export class AppModule {}
