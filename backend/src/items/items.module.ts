import { Module } from '@nestjs/common';

import { FirestoreModule } from '../firestore/firestore.module';
import { ItemsController } from './items.controller';
import { ItemsService } from './items.service';

@Module({
  imports: [FirestoreModule],
  controllers: [ItemsController],
  providers: [ItemsService],
})
export class ItemsModule {}
