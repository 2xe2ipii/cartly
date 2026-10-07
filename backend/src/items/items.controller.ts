import { Body, Controller, Get, Post } from '@nestjs/common';

import { UserId } from '../common/user-id.decorator';
import { ItemsService, type Item } from './items.service';

@Controller('items')
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) {}

  @Get()
  list(@UserId() userId: string): Promise<{ items: Item[] }> {
    return this.itemsService.list(userId);
  }

  @Post()
  create(@UserId() userId: string, @Body() body: unknown): Promise<{ id: string }> {
    return this.itemsService.create(userId, body);
  }
}
